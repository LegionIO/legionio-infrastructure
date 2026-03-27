terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

variable "vault_address" {
  type        = string
  description = "Vault server address"
}

variable "vault_namespace" {
  type        = string
  default     = "legionio"
  description = "Vault namespace for LegionIO"
}

provider "vault" {
  address   = var.vault_address
  namespace = var.vault_namespace
}

# KV v2 secret engine for LegionIO
resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv-v2"
  description = "LegionIO KV secrets"
}

# Transit engine for encryption operations
resource "vault_mount" "transit" {
  path        = "transit"
  type        = "transit"
  description = "LegionIO transit encryption"
}

resource "vault_transit_secret_backend_key" "data" {
  backend = vault_mount.transit.path
  name    = "legionio-data"
  type    = "aes256-gcm96"
}

# PKI engine for mTLS certificates
resource "vault_mount" "pki" {
  path                  = "pki"
  type                  = "pki"
  max_lease_ttl_seconds = 31536000 # 1 year
  description           = "LegionIO internal PKI"
}

resource "vault_pki_secret_backend_role" "internal" {
  backend          = vault_mount.pki.path
  name             = "internal"
  ttl              = 86400 # 24 hours
  max_ttl          = 259200 # 72 hours
  allow_localhost  = true
  allowed_domains  = ["legionio.local", "service.consul"]
  allow_subdomains = true
  key_type         = "ec"
  key_bits         = 256
}

# Database secret engine for PostgreSQL dynamic credentials
resource "vault_mount" "postgresql" {
  path        = "postgresql"
  type        = "database"
  description = "LegionIO PostgreSQL dynamic credentials"
}

# RabbitMQ secret engine
resource "vault_mount" "rabbitmq" {
  path        = "rabbitmq"
  type        = "rabbitmq"
  description = "LegionIO RabbitMQ dynamic credentials"
}

# Policies per service role
locals {
  service_roles = ["core", "cognitive", "ai", "knowledge", "operations", "api", "teams", "slack"]
}

resource "vault_policy" "services" {
  for_each = toset(local.service_roles)
  name     = "legionio-${each.key}"

  policy = <<-EOT
    # read own service config from KV
    path "kv/data/services/${each.key}/*" {
      capabilities = ["read", "list"]
    }

    # read shared config
    path "kv/data/shared/*" {
      capabilities = ["read", "list"]
    }

    # per-user secrets (read/write own path)
    path "kv/data/users/{{identity.entity.aliases.+.name}}/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "kv/metadata/users/{{identity.entity.aliases.+.name}}/*" {
      capabilities = ["list", "read", "delete"]
    }

    # transit encrypt/decrypt
    path "transit/encrypt/legionio-data" {
      capabilities = ["update"]
    }
    path "transit/decrypt/legionio-data" {
      capabilities = ["update"]
    }

    # request mTLS certs
    path "pki/issue/internal" {
      capabilities = ["update"]
    }

    # dynamic PostgreSQL credentials
    path "postgresql/creds/${each.key}" {
      capabilities = ["read"]
    }

    # dynamic RabbitMQ credentials
    path "rabbitmq/creds/${each.key}" {
      capabilities = ["read"]
    }

    # token self-management
    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
  EOT
}

# AI role gets additional access to LLM API keys
resource "vault_policy" "ai_extra" {
  name = "legionio-ai-llm-keys"

  policy = <<-EOT
    path "kv/data/llm/*" {
      capabilities = ["read", "list"]
    }
  EOT
}
