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
func TestProjectLifecycleIsRejected(t *testing.T) {
	for _, action := range []string{"project.start", "project.stop"} {
		if _, _, err := resolve(request{Action: action, Target: "/srv/projects/demo", Actor: "operator"}); err == nil {
			t.Fatalf("%s must not be exposed through the privileged broker", action)
		}
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
	if err := os.MkdirAll(root, 0755); err != nil {
		t.Skipf("cannot prepare /srv/projects in this test environment: %v", err)
	}
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
