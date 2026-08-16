package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const version = "1.0.0"

var safeName = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,47}$`)

type request struct {
	Action string   `json:"action"`
	Target string   `json:"target"`
	Args   []string `json:"args"`
	Actor  string   `json:"actor"`
}
type response struct {
	OK         bool   `json:"ok"`
	ExitCode   int    `json:"exitCode"`
	Output     string `json:"output"`
	DurationMS int64  `json:"durationMs"`
	Error      string `json:"error,omitempty"`
}

func main() {
	socket := env("AIOPS_BROKER_SOCKET", "/run/aiops-dashboard/broker.sock")
	audit := env("AIOPS_AUDIT_LOG", "/var/log/aiops-dashboard/audit.jsonl")
	if err := os.MkdirAll(filepath.Dir(socket), 0750); err != nil {
		panic(err)
	}
	_ = os.Remove(socket)
	listener, err := net.Listen("unix", socket)
	if err != nil {
		panic(err)
	}
	defer listener.Close()
	if err = os.Chmod(socket, 0660); err != nil {
		panic(err)
	}
	slog.Info("broker ready", "version", version, "socket", socket)
	for {
		conn, err := listener.Accept()
		if err != nil {
			panic(err)
		}
		go handle(conn, audit)
	}
}
func handle(conn net.Conn, audit string) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(35 * time.Second))
	var r request
	if err := json.NewDecoder(bufio.NewReader(io.LimitReader(conn, 16384))).Decode(&r); err != nil {
		write(conn, response{Error: "invalid request"})
		return
	}
	start := time.Now()
	cmd, args, err := resolve(r)
	if err != nil {
		result := response{Error: err.Error(), DurationMS: time.Since(start).Milliseconds()}
		write(conn, result)
		logAudit(audit, r, result)
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	out, runErr := exec.CommandContext(ctx, cmd, args...).CombinedOutput()
	result := response{OK: runErr == nil, Output: truncate(string(out), 16384), DurationMS: time.Since(start).Milliseconds()}
	if runErr != nil {
		result.ExitCode = 1
		result.Error = "operation failed"
		var exit *exec.ExitError
		if errors.As(runErr, &exit) {
			result.ExitCode = exit.ExitCode()
		}
	}
	write(conn, result)
	logAudit(audit, r, result)
}
func resolve(r request) (string, []string, error) {
	if r.Actor == "" || len(r.Actor) > 64 {
		return "", nil, errors.New("invalid actor")
	}
	switch r.Action {
	case "manager.verify":
		if r.Target != "" || len(r.Args) > 0 {
			return "", nil, errors.New("manager.verify accepts no target or arguments")
		}
		return "/usr/local/bin/manager-suite", []string{"verify"}, nil
	case "project.start", "project.stop", "project.verify", "project.backup":
		path, err := projectPath(r.Target)
		if err != nil {
			return "", nil, err
		}
		if len(r.Args) > 0 {
			return "", nil, errors.New("project operation arguments are not allowed")
		}
		verb := map[string]string{"project.start": "up", "project.stop": "down", "project.verify": "verify", "project.backup": "backup"}[r.Action]
		return "/usr/local/bin/project-manager", []string{verb, path}, nil
	case "collection.crawl":
		path, err := projectPath(r.Target)
		if err != nil {
			return "", nil, err
		}
		if len(r.Args) != 1 || !safeName.MatchString(r.Args[0]) {
			return "", nil, errors.New("collection.crawl requires one safe collection name")
		}
		return "/usr/local/bin/collection-manager", []string{"crawl", path, r.Args[0]}, nil
	case "collection.verify":
		path, err := projectPath(r.Target)
		if err != nil {
			return "", nil, err
		}
		if len(r.Args) > 0 {
			return "", nil, errors.New("collection.verify arguments are not allowed")
		}
		return "/usr/local/bin/collection-manager", []string{"verify", path}, nil
	default:
		return "", nil, errors.New("operation is not allowlisted")
	}
}
func projectPath(raw string) (string, error) {
	if !strings.HasPrefix(raw, "/srv/projects/") || strings.ContainsAny(raw, "\x00\n\r\t") {
		return "", errors.New("project target is outside /srv/projects")
	}
	clean := filepath.Clean(raw)
	if clean == "/srv/projects" || filepath.Dir(clean) != "/srv/projects" {
		return "", errors.New("project target must be one direct child of /srv/projects")
	}
	resolved, err := filepath.EvalSymlinks(clean)
	if err != nil {
		return "", errors.New("project target does not exist")
	}
	if filepath.Dir(resolved) != "/srv/projects" {
		return "", errors.New("project symlink escapes /srv/projects")
	}
	return resolved, nil
}
func write(conn net.Conn, r response) { _ = json.NewEncoder(conn).Encode(r) }
func logAudit(path string, r request, result response) {
	_ = os.MkdirAll(filepath.Dir(path), 0750)
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0640)
	if err != nil {
		return
	}
	defer f.Close()
	entry := map[string]any{"time": time.Now().UTC().Format(time.RFC3339Nano), "actor": r.Actor, "action": r.Action, "target": r.Target, "args": r.Args, "ok": result.OK, "exitCode": result.ExitCode, "durationMs": result.DurationMS}
	_ = json.NewEncoder(f).Encode(entry)
}
func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "\n[truncated]"
}
func env(k, v string) string {
	if x := os.Getenv(k); x != "" {
		return x
	}
	return v
}
