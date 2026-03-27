terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

# Redis doesn't have a native Terraform provider, so this module
# stores the Redis connection config in Vault for services to consume.
# For actual Redis ACL setup, use the provisioner block or a config management tool.

variable "vault_address" {
  type        = string
  description = "Vault server address"
}

variable "vault_namespace" {
  type        = string
  default     = "legionio"
  description = "Vault namespace"
}

variable "redis_host" {
  type        = string
  description = "Redis server host"
}

variable "redis_port" {
  type        = number
  default     = 6379
  description = "Redis server port"
}

variable "redis_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Redis password (empty if no auth)"
}

provider "vault" {
  address   = var.vault_address
  namespace = var.vault_namespace
}

locals {
  redis_url = var.redis_password != "" ? "redis://:${var.redis_password}@${var.redis_host}:${var.redis_port}/0" : "redis://${var.redis_host}:${var.redis_port}/0"
}

# store redis connection info in Vault KV
resource "vault_kv_secret_v2" "redis" {
  mount = "kv"
  name  = "shared/redis"

  data_json = jsonencode({
    host     = var.redis_host
    port     = var.redis_port
    password = var.redis_password
    url      = local.redis_url
  })
}
