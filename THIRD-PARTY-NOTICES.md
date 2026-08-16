# Third-Party Notices and Attributions

SIMHA AiOps is Copyright (c) 2026 Simha.Online and is distributed under the
MIT License in `LICENSE`. This file identifies external projects that SIMHA
AiOps can build, invoke, manage, or integrate with. Each project remains the
property of its respective copyright holder and is governed by its own license,
terms, and notices.

SIMHA AiOps does not claim ownership of these projects. Unless a source file or
package is explicitly present in this repository, the project is an external
runtime or dependency and is not relicensed by the SIMHA AiOps MIT License.
Operators must review the exact version's upstream license before production
redistribution.

## Application and runtime credits

| Project | How SIMHA AiOps uses or integrates it | Upstream |
|---|---|---|
| Next.js | Dashboard web application runtime | https://github.com/vercel/next.js |
| React | Dashboard UI library | https://github.com/facebook/react |
| NestJS | Dashboard API framework | https://github.com/nestjs/nest |
| Fastify | NestJS HTTP adapter | https://github.com/fastify/fastify |
| TypeScript | Web/API compilation and type checking | https://github.com/microsoft/TypeScript |
| Node.js | Dashboard build/runtime base image | https://github.com/nodejs/node |
| Go | Privileged broker implementation/build toolchain | https://go.dev/ |
| Python | Telemetry collector and runtime support | https://www.python.org/ |
| Docker Engine/Compose | Runtime and project isolation | https://github.com/docker/compose |
| Nginx | TLS and authenticated reverse-proxy edge | https://nginx.org/ |
| Certbot | Certificate issuance/renewal integration | https://github.com/certbot/certbot |
| WireGuard | VPN runtime managed by `wireguard-manager` | https://www.wireguard.com/ |
| Forgejo | Optional source-control service | https://codeberg.org/forgejo/forgejo |
| Forgejo Runner | Optional isolated CI execution plane | https://code.forgejo.org/forgejo/runner |

## AI, provider, and collection credits

| Project/service | How SIMHA AiOps uses or integrates it | Upstream |
|---|---|---|
| LiteLLM | Provider gateway and model routing | https://github.com/BerriAI/litellm |
| Ollama | Local loopback API and Ollama Cloud model registration | https://github.com/ollama/ollama |
| Ollama Cloud | Cloud-hosted model service | https://ollama.com/ |
| NVIDIA NIM | Provider model discovery and optional inference endpoint | https://build.nvidia.com/ |
| OpenRouter | Provider model discovery and optional inference endpoint | https://openrouter.ai/ |
| Scrapling | Pinned, restricted collection worker launched by `collection-manager` | https://github.com/D4Vinci/Scrapling |
| Goose | Optional project-local CLI installation integration | https://github.com/aaif-goose/goose |

The provider names, product names, logos, model names, and service marks above
are used only to identify compatibility or integration. SIMHA AiOps is not
endorsed by, sponsored by, or affiliated with those organizations unless a
separate written agreement states otherwise.

## Referenced products not bundled

LibreChat, LobeHub, AnythingLLM, and Langflow were considered as product
references during UX planning. SIMHA Studio is implemented as a first-party
interface and does not bundle, fork, or redistribute their application code.

## Trademark statement

All trademarks, service marks, trade names, product names, logos, and brands
mentioned in this repository are the property of their respective owners. Use
of a name or mark is for identification, interoperability, documentation, or
compatibility purposes only and does not imply endorsement, sponsorship,
affiliation, or ownership.

Third-party license texts and notices remain the responsibility of the relevant
upstream project and any deployment or redistribution package that includes
their artifacts. When distributing a bundled image or derivative package,
include the applicable upstream notices and license texts required by each
dependency.
