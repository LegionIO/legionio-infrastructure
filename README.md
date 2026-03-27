# legion-infrastructure

Container images, Nomad job specs, and Terraform modules for deploying LegionIO as a set of always-on services.

## Architecture

LegionIO runs as layered container images, each adding extensions for a specific role:

```
ruby:3.4-slim
  └── base        legionio + core libs + lex-node + su-exec
        └── core        15 core extensions (scheduler, health, tasker, ...)
              ├── ai            7 LLM providers + eval + prompt
              ├── cognitive     13 agentic-* + synapse/mesh/react/tick/extinction/...
              ├── knowledge     apollo + knowledge + legion-apollo + legion-llm
              ├── operations    autofix + swarm-github + mind-growth + infra-monitor + ...
              ├── api           legion-mcp + webhook + http (Puma on port 4567)
              └── integrations/
                    ├── teams   microsoft_teams + kerberos (+ krb5 system libs)
                    └── slack   slack (polling enabled)
```

Images are built with [Packer](https://www.packer.io/) (docker builder) and pushed to both GHCR and Docker Hub.

## Quick Start

### Build an image locally

```bash
cd services/base
packer init .
packer build -var "version=dev" .
```

### Deploy a Nomad job

```bash
cd services/core
nomad job run -var "rabbitmq_url=amqp://rabbitmq:5672" core.nomad.hcl
```

### Provision infrastructure

```bash
cd terraform/vault
terraform init
terraform plan -var "vault_address=https://vault:8200"
terraform apply
```

## Services

| Service | Role | Extensions | Default Replicas | CPU/Mem |
|---|---|---|---|---|
| **base** | - | legionio, core libs, lex-node | - | - |
| **core** | worker | scheduler, health, tasker, log, audit, +10 more | 2 | 500/512MB |
| **ai** | worker | azure-ai, bedrock, claude, foundry, gemini, openai, xai, eval, prompt | 2 | 1000/1024MB |
| **cognitive** | worker | 13 agentic-*, synapse, mesh, react, tick, extinction, privatecore, coldstart, swarm | 2 | 1000/1024MB |
| **knowledge** | worker | apollo, knowledge, legion-apollo, legion-llm | 2 | 1000/1024MB |
| **operations** | worker | autofix, swarm-github, mind-growth, pilot-infra-monitor, cost-scanner, onboard | 1 | 500/512MB |
| **api** | api | legion-mcp, webhook, http | 2 | 500/512MB |
| **teams** | worker | microsoft_teams, kerberos | 1 | 500/512MB |
| **slack** | worker | slack | 1 | 250/256MB |

## Terraform Modules

| Module | Purpose |
|---|---|
| `terraform/vault/` | KV v2, Transit, PKI, database + RabbitMQ secret engines, per-role policies |
| `terraform/rabbitmq/` | Vhost, HA + TTL policies, per-role users |
| `terraform/consul/` | Partition, namespace, service intentions, ACL policy + token |
| `terraform/postgresql/` | Databases (legionio + apollo), roles, pgvector + pg_trgm extensions, grants |
| `terraform/redis/` | Connection config stored in Vault KV |
| `terraform/entra/` | Azure AD app registration with Graph API permissions for Teams |

## CI/CD

Push to `main` triggers automatic image builds via GitHub Actions. The pipeline respects the dependency chain:

1. **base** builds first (if changed)
2. **core** builds after base
3. All other images build in parallel after core

Changes to `services/base/` cascade a full rebuild. Changes to a leaf service only rebuild that service.

Manual builds: use the `workflow_dispatch` trigger with the `all` option or pick a specific service.

### Required Secrets

| Secret | Used by |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub push |
| `DOCKERHUB_TOKEN` | Docker Hub push |
| `GITHUB_TOKEN` | GHCR push (built-in) |

## Configuration

Each service bakes a default `settings.json` into the image. Override at runtime by mounting a config volume:

```bash
docker run -v /path/to/settings.json:/opt/legion/config/settings.json ghcr.io/legionio/legion-core:latest
```

Nomad jobs use `template` blocks to generate settings from job variables, with `change_mode = "restart"` for automatic reloads.

## Infrastructure Requirements

- **RabbitMQ** - AMQP 0.9.1 message broker
- **PostgreSQL** - Primary storage + Apollo knowledge store (with pgvector)
- **Redis** - Caching layer
- **HashiCorp Vault** - Secrets, dynamic credentials, mTLS PKI
- **HashiCorp Consul** - Service discovery and mesh (optional but recommended)
- **HashiCorp Nomad** - Container orchestration (or any OCI-compatible scheduler)

## License

Apache-2.0
