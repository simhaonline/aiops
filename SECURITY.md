# Security Policy - SIMHA AiOps 1.0.0

## Supported platform

The maintained suite is validated for Ubuntu Server 24.04 LTS.

## Reporting

Do not open a public issue containing credentials, private keys, access tokens, production IP allowlists, or customer data.

## Release integrity

The bootstrap verifies all downloaded manager scripts against `SHA256SUMS.txt` before installing them. For reproducible production deployment, pin `AIOPS_REF` to a release tag or commit.

Project skills and plugins are executable supply-chain inputs. Import only
reviewed local sources, retain `.aiops/ai/assets.lock`, run `project-manager
ai-audit`, and never place credentials in AGENTS, skill, plugin or MCP metadata.

Web collection requires authorization. `collection-manager` rejects non-HTTPS,
authenticated, localhost, and literal non-public IP targets, but operators must
also enforce network egress policy against DNS rebinding and redirects. Respect
robots directives, site terms, privacy law, retention requirements and source
rate limits. Never collect personal, sensitive, paywalled or authenticated data
without explicit legal and data-owner approval.

Checksums protect against accidental corruption or inconsistent payloads. They are not a substitute for repository/account security or signed-release provenance.

## Runtime exposure

Keep application backends on loopback whenever supported. Use `nginx-manager` as the intended public TLS edge.

## Repository scope

Only maintained executable managers, active QA, installer files, release
metadata, and current Markdown operations documentation are published.
