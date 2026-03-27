# LegionIO Infrastructure

**Parent**: See the main [LegionIO CLAUDE.md](https://github.com/LegionIO/LegionIO) for framework context.

## What is This Repo?

Container image definitions (Packer), Nomad job specs, and Terraform modules for deploying LegionIO as always-on services. This is the deployment/infrastructure companion to the LegionIO framework.

## Repository Layout

```
legion-infrastructure/
├── services/                    # Container images + Nomad jobs (one folder per role)
│   ├── base/                    # Layer 0: ruby:3.4-slim + legionio + core libs + lex-node
│   │   ├── base.pkr.hcl
│   │   └── entrypoint.sh
│   ├── core/                    # Layer 1: 15 core extensions
│   │   ├── core.pkr.hcl
│   │   ├── core.nomad.hcl
│   │   └── settings.json
│   ├── ai/                      # Layer 2: 7 LLM providers + eval + prompt
│   ├── cognitive/               # Layer 2: 13 agentic-* + synapse/mesh/react/tick/...
│   ├── knowledge/               # Layer 2: apollo + knowledge
│   ├── operations/              # Layer 2: autofix + swarm-github + mind-growth + pilots
│   ├── api/                     # Layer 2: legion-mcp + webhook + http (process role: api)
│   └── integrations/
│       ├── teams/               # Layer 2: microsoft_teams + kerberos
│       └── slack/               # Layer 2: slack (polling enabled)
├── terraform/                   # Infrastructure-as-code modules
│   ├── vault/                   # Secret engines, policies, PKI
│   ├── rabbitmq/                # Vhost, HA policies, users
│   ├── consul/                  # Partition, intentions, ACLs
│   ├── postgresql/              # Databases, roles, extensions (pgvector)
│   ├── redis/                   # Connection config in Vault KV
│   └── entra/                   # Azure AD app registration for Teams
├── .github/workflows/           # CI: ordered image builds
│   ├── build-image.yml          # Orchestrator (detects changes, enforces build order)
│   └── build-single-image.yml   # Reusable (packer init + build + dual-push)
└── _archived/                   # Legacy terraform (do not reference)
```

## Image Layering

```
base → core → [ai | cognitive | knowledge | operations | api | teams | slack]
```

- **base** and **core** are shared layers; all role images inherit from core
- Each role image adds only its own extensions via `gem install`
- Role filtering uses `LEGION_ROLE_PROFILE` (maps to LegionIO's `role.profile` setting)
- Process role (`LEGION_PROCESS_ROLE`) controls which subsystems boot: `worker` (most services) or `api` (api service)

## CI Build Order

Layer 0 (base) → Layer 1 (core) → Layer 2 (all others in parallel). Changes to base cascade a full rebuild. Changes to a leaf only rebuild that leaf.

## Key Conventions

- **Packer**, not Dockerfile — all images use `.pkr.hcl` with the `docker` builder
- **Dual registry push** — every image goes to both `ghcr.io/legionio` and `docker.io/legionio`
- **Settings override** — images bake a default `settings.json`; mount `/opt/legion/config/settings.json` to override
- **Nomad jobs** use `template` blocks for settings with `change_mode = "restart"`
- **Vault dynamic creds** — Terraform modules set up static placeholder passwords; production uses Vault's database/rabbitmq secret engines
- **Consul service discovery** — Nomad jobs default to `*.service.consul` hostnames

## Terraform Modules

Each module is a self-contained root module. They are examples/starting points — users copy and customize for their environment.

| Module | Provider | Key Resources |
|---|---|---|
| vault | hashicorp/vault | KV v2, Transit key, PKI role, DB + RabbitMQ engines, 8 service policies |
| rabbitmq | cyrilgdn/rabbitmq | legionio vhost, HA + TTL policies, per-role users |
| consul | hashicorp/consul | legionio partition, service intentions, ACL policy + token |
| postgresql | cyrilgdn/postgresql | legionio + legionio_apollo DBs, pgvector, roles, grants |
| redis | hashicorp/vault | Connection config stored in Vault KV (no native Redis provider) |
| entra | hashicorp/azuread | App registration, Graph API permissions, service principal |

## Do Not Reference

- `_archived/` — legacy terraform, superseded by `terraform/` modules
- Any `.terraform/` directories
- Any `*.pem`, `*.crt`, `*.key` files

---

**Last Updated**: 2026-03-27
**Maintained By**: Matthew Iverson (@Esity)
