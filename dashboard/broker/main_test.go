package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRejectsUnlistedAction(t *testing.T) {
	if _, _, err := resolve(request{Action: "shell.exec", Actor: "operator"}); err == nil {
		t.Fatal("arbitrary shell action accepted")
	}
}
func TestProjectPathRejectsEscape(t *testing.T) {
	if _, err := projectPath("/etc"); err == nil {
		t.Fatal("outside path accepted")
	}
}
func TestCollectionNameValidation(t *testing.T) {
	if safeName.MatchString("../../root") {
		t.Fatal("unsafe collection name accepted")
	}
}
func TestProjectPathAcceptsDirectChild(t *testing.T) {
	if os.Geteuid() != 0 {
		t.Skip("test uses /srv/projects")
	}
	root := "/srv/projects"
	_ = os.MkdirAll(root, 0755)
	dir, err := os.MkdirTemp(root, "broker-test-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)
	got, err := projectPath(dir)
	if err != nil || got != filepath.Clean(dir) {
		t.Fatalf("got %q, %v", got, err)
	}
}
