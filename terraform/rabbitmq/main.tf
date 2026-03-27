terraform {
  required_providers {
    rabbitmq = {
      source  = "cyrilgdn/rabbitmq"
      version = "~> 1.8"
    }
  }
}

variable "rabbitmq_endpoint" {
  type        = string
  description = "RabbitMQ management API endpoint"
}

variable "rabbitmq_username" {
  type        = string
  description = "RabbitMQ admin username"
}

variable "rabbitmq_password" {
  type        = string
  sensitive   = true
  description = "RabbitMQ admin password"
}

provider "rabbitmq" {
  endpoint = var.rabbitmq_endpoint
  username = var.rabbitmq_username
  password = var.rabbitmq_password
}

# vhost for LegionIO
resource "rabbitmq_vhost" "legionio" {
  name = "legionio"
}

# HA policy: mirror queues across 2 nodes
resource "rabbitmq_policy" "ha" {
  name  = "ha-legionio"
  vhost = rabbitmq_vhost.legionio.name

  policy {
    pattern  = ".*"
    priority = 0
    apply_to = "queues"

    definition = {
      "ha-mode"      = "exactly"
      "ha-params"    = 2
      "ha-sync-mode" = "automatic"
    }
  }
}

# message TTL policy for dead-letter prevention
resource "rabbitmq_policy" "ttl" {
  name  = "ttl-legionio"
  vhost = rabbitmq_vhost.legionio.name

  policy {
    pattern  = ".*"
    priority = 1
    apply_to = "queues"

    definition = {
      "message-ttl" = 86400000 # 24 hours in ms
    }
  }
}

# service accounts per role
locals {
  service_roles = ["core", "cognitive", "ai", "knowledge", "operations", "api", "teams", "slack"]
}

resource "rabbitmq_user" "services" {
  for_each = toset(local.service_roles)
  name     = "legion-${each.key}"
  password = "changeme-use-vault-dynamic-creds"
  tags     = ["management"]
}

resource "rabbitmq_permissions" "services" {
  for_each = toset(local.service_roles)
  user     = rabbitmq_user.services[each.key].name
  vhost    = rabbitmq_vhost.legionio.name

  permissions {
    configure = ".*"
    write     = ".*"
    read      = ".*"
  }
}
