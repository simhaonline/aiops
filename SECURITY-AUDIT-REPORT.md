# SIMHA AiOps Security and Architecture Audit

**Audit scope:** release `1.0.0`, current `main` tree  
**Audit mode:** read-only source review, focused adversarial checks, and the existing release regression suite  
**Status:** critical broker and dashboard listener findings remediated in the
follow-up commit; remaining findings are documented remediation work

## Executive summary

The existing `qa/validate-release.sh` suite passes, and no embedded private keys,
real provider credentials, SQL layer, direct `innerHTML`, or shell invocation in
the Go broker were found. The most important unresolved risk is the privileged
dashboard path that runs user-editable project Compose definitions as root.

## Findings

| File/location | Severity | Finding | Impact | Recommended fix |
|---|---:|---|---|---|
| `dashboard/broker/main.go:102-111`; `scripts/project-manager:52-64` | Remediated | The previous `project.start` path could invoke user-editable Compose and feature YAML through a root broker | A project owner could have added privileged containers, host mounts, devices, or host networking | `project.start` and `project.stop` are now rejected by the broker/API; future project lifecycle must use a rootless project service and strict Compose policy validator |
| `scripts/aiops-dashboard-manager:84-99` | Remediated | Dashboard web container previously set `HOSTNAME=0.0.0.0` while the documented boundary is loopback-only | Port 4600 could bypass the intended Nginx authentication/TLS edge | `HOSTNAME` is now set to `127.0.0.1`; deployment verification should still check listeners |
| Root installers and mutable dependencies | High | Codex/Ollama installers, latest pip packages, mutable project images, and unpinned tool installs are executed or built | Upstream compromise can become root or service-account code execution | Pin versions, release digests, installer SHA-256 values, package hashes, and container image digests |
| `dashboard/broker/main.go:44-59` | High | Any process in the broker socket group can call privileged operations without proving the dashboard token | A compromised local group member can invoke operations and spoof `actor` | Validate Unix peer credentials or use broker-side HMAC authentication |
| `scripts/ollama-manager:672-847` | High | `chat`, `test`, and `benchmark` accept models outside the approved Cloud catalog | Free-model policy can be bypassed and paid/unapproved provider usage can occur | Validate every model against an approved local-to-remote mapping |
| `scripts/collection-manager:32-50,103-126` | High | Hostname validation and crawler resolution are separate DNS operations | DNS rebinding can turn an apparently public URL into an internal target | Use a DNS-aware egress proxy/firewall and pin validated addresses |
| `dashboard/broker/main.go:53-89` | Medium | Unlimited broker goroutines and child processes | Local clients can exhaust processes, memory, file descriptors, or Docker capacity | Add a bounded semaphore, request limits, and systemd resource limits |
| `dashboard/broker/main.go:152-160` | Medium | Audit write errors are ignored and concurrent writes are not serialized | Privileged actions may lack reliable audit evidence | Serialize writes, return errors, and fail closed or alert on audit-storage failure |
| `dashboard/apps/api/src/operations.controller.ts:6-11` | Medium | No explicit request body, array, string, or rate limits | Authenticated clients can create parsing/socket resource pressure | Configure Fastify `bodyLimit`, DTO size limits, and rate limiting |
| `dashboard/apps/api/src/platform.service.ts:9-15` | Medium | Empty catches hide telemetry, project, and broker failures | Operators receive misleading fallback states and lose incident context | Add structured, redacted server-side diagnostics |
| `dashboard/telemetry/collector.py:34-49` | Medium | Threaded HTTP server has no request timeout or thread cap | Slow local clients can retain worker threads and sockets | Set connection timeouts, daemon threads, and process resource limits |
| `scripts/project-manager:66-96` | Medium | Port availability check and reservation are not atomic | Concurrent project initialization can assign duplicate ports | Use an exclusive lock and atomic reservation files |
| `scripts/project-manager:238-354` | Medium | Asset and MCP state updates have no project lock | Concurrent updates can lose changes or produce inconsistent configuration | Lock read/modify/write operations and atomically replace files |
| `scripts/collection-manager:230-246` | Medium | Project paths are interpolated into systemd `ExecStart` without systemd escaping | `%`, backslashes, or unusual paths may corrupt a generated unit | Use `systemd-escape` or reject systemd-unsafe characters |
| `scripts/litellm-manager:165-212` | Low | Temporary model refresh files are not cleaned on every failure path | Failed refreshes can leave root-readable temporary files | Add cleanup traps on every temporary file path |
| `dashboard/apps/web/app/ui/dashboard-shell.tsx:29-54` | Low | A malformed successful capability response can leave `selected` undefined | Studio can crash while rendering the composer | Validate response shape and always use a known fallback modality |

## Critical Compose boundary proof of concept

A project owner can add this to `.aiops/features/attacker.yaml`:

```yaml
services:
  attacker:
    image: alpine:latest
    privileged: true
    volumes:
      - /:/host:rw
    command: ["sh", "-c", "touch /host/tmp/aiops-compromised"]
```

Before remediation, if the dashboard broker accepted `project.start`, it invoked
`/usr/local/bin/project-manager up /srv/projects/demo`. The project manager
includes project-local Compose and feature files in the Docker invocation. Since
the broker is root and has Docker access, this crosses project isolation.

Immediate defensive change:

```go
case "project.start", "project.stop":
    return "", nil, errors.New(
        "project lifecycle is not available through the privileged dashboard broker; use a rootless project service",
    )
```

The immediate remediation rejects this operation at both the API and broker.
The preferred long-term design is a rootless per-project Docker identity with a
strict Compose schema validator and immutable image references.

## Web listener proof of concept

The dashboard manager currently writes:

```yaml
network_mode: host
environment:
  HOSTNAME: 0.0.0.0
```

After installation, run:

```bash
ss -lntp | grep ':4600'
```

The safe result must be `127.0.0.1:4600` or `[::1]:4600`, not
`0.0.0.0:4600`. Required change:

```yaml
HOSTNAME: 127.0.0.1
```

## Resource and concurrency review

- Go broker connections are closed with `defer`, and child operations have a
  timeout, but global concurrency is unlimited.
- Python telemetry uses a threaded server without a socket timeout.
- LiteLLM refresh temporary files do not have complete failure cleanup.
- Project port allocation is check-then-use and needs locking.
- MCP and AI asset updates can lose concurrent changes without a project lock.
- `PlatformService` accumulates broker response data without an explicit client
  maximum, although broker output is bounded.

## Architectural anti-patterns

- `scripts/aiops` and `scripts/manager-suite` duplicate manager registries and
  phase knowledge.
- `PlatformService` combines telemetry, project discovery, and broker transport.
- The root broker has excessive indirect power through project lifecycle tools.
- The Studio UI capability surface is ahead of conversation persistence,
  streaming, media workers, and workflow execution services.
- Release integrity uses checksums but does not yet provide signed release
  provenance or Sigstore-style attestations.

## Recommended remediation order

1. Remove or redesign brokered project startup/stop operations.
2. Bind the dashboard web service explicitly to loopback.
3. Add broker peer authentication and concurrency limits.
4. Enforce the approved Ollama model mapping for every Cloud request.
5. Pin root installers, packages, base images, and external tool releases.
6. Add API body, field, response, and rate limits.
7. Add project/MCP/asset locking and atomic reservations.
8. Add DNS-aware collection egress controls.
9. Add telemetry timeouts and structured error reporting.
10. Add adversarial regression tests for each finding.
