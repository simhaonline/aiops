# SIMHA Studio product architecture

SIMHA Studio is a first-party user experience for the AiOps Manager Suite. It does not embed, fork, or ship code from LibreChat, LobeHub, AnythingLLM, Langflow, or Scrapling. Those products informed the problem space only.

## Product surfaces

| Surface | Primary capability |
| --- | --- |
| Studio | Multimodal conversations and creation with project context |
| Codebases | Repository indexing, architecture maps, diffs, reviews, tests, and isolated coding agents |
| Knowledge | PDF, office document, Markdown, table, and allowlisted web ingestion with citations |
| Media | Image understanding/generation/editing, video analysis/generation/subtitles, and speech transcription/synthesis |
| Workflows | Versioned model/tool graphs, branches, retries, approvals, schedules, and run traces |
| Registry | Discovery and governed publication of skills, agents, MCP servers, and plugins |
| Projects | Isolated instructions, data, AI assets, secrets, runtime state, and recovery points |
| Operations | Health, audits, verification, backups, policy findings, and allowlisted manager actions |

Translation is a cross-modal capability: text and documents retain structure; audio can be dubbed; video can produce translated subtitles and alternate audio tracks. Model selection is capability-aware and goes through LiteLLM. A verified-free-first policy can use Ollama Cloud, NVIDIA NIM, or OpenRouter, while paid or local fallbacks must remain explicit.

## Execution boundary

The browser never receives provider credentials. The web application calls the API, the API delegates inference to LiteLLM, and privileged infrastructure mutations go through the narrow Unix-socket broker allowlist. Uploads and externally discovered artifacts enter quarantine before parsing or execution.

```text
Browser -> SIMHA API -> LiteLLM -> approved model provider
                    -> project-scoped retrieval and media workers
                    -> Unix broker -> allowlisted manager operation
Public discovery -> quarantine -> scan -> human review -> immutable registry version -> explicit project install
```

## Delivery sequence

The 1.0.0 UI and API expose the complete navigation and capability contract. Functional delivery should proceed in bounded layers: conversation persistence and streaming; uploads and extraction; repository/RAG indexing; media workers; translation pipelines; workflow execution; then governed registry collection. Every layer must add quotas, provenance, audit events, retention controls, accessibility, mobile behavior, retry/recovery, and end-to-end tests before production enablement.

Registry collection is intentionally not an automatic internet-wide installation mechanism. Crawlers may collect metadata only from configured public sources, respect source policies, deduplicate and snapshot records, and place every candidate in quarantine. Approval and installation remain separate human actions.
