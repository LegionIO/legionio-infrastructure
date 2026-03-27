variable "image" {
  type        = string
  default     = "ghcr.io/legionio/legion-api:latest"
  description = "Container image for legion-api"
}

variable "count" {
  type        = number
  default     = 2
  description = "Number of API instances"
}

variable "rabbitmq_url" {
  type        = string
  default     = "amqp://rabbitmq.service.consul:5672"
  description = "RabbitMQ connection URL"
}

variable "redis_url" {
  type        = string
  default     = "redis://redis.service.consul:6379/0"
  description = "Redis connection URL"
}

variable "postgres_host" {
  type        = string
  default     = "postgresql.service.consul"
  description = "PostgreSQL host"
}

variable "vault_addr" {
  type        = string
  default     = "https://vault.service.consul:8200"
  description = "Vault server address"
}

job "legion-api" {
  datacenters = ["dc1"]
  type        = "service"

  group "api" {
    count = var.count

    network {
      port "http" {
        to = 4567
      }
    }

    service {
      name = "legion-api"
      port = "http"
      tags = ["traefik.enable=true"]

      check {
        type     = "http"
        path     = "/health"
        interval = "15s"
        timeout  = "5s"
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "api" {
      driver = "docker"

      config {
        image = var.image
        ports = ["http"]
      }

      env {
        LEGION_PROCESS_ROLE = "api"
        LEGION_ROLE_PROFILE = "custom"
      }

      template {
        data        = <<-EOF
        {
          "process": { "role": "api" },
          "role": {
            "profile": "custom",
            "extensions": [
              "codegen", "conditioner", "exec", "health", "lex", "llm-gateway",
              "log", "metering", "node", "ping", "scheduler", "tasker",
              "task_pruner", "telemetry", "transformer",
              "webhook", "http"
            ]
          },
          "transport": { "url": "${var.rabbitmq_url}", "vhost": "legionio" },
          "cache": { "driver": "redis", "url": "${var.redis_url}" },
          "data": { "adapter": "postgres", "host": "${var.postgres_host}", "port": 5432, "database": "legionio", "pool_size": 15 },
          "logging": { "level": "info", "json": true },
          "vault": { "address": "${var.vault_addr}", "namespace": "legionio" },
          "api": { "enabled": true, "bind": "0.0.0.0", "port": 4567 },
          "mcp": { "enabled": true }
        }
        EOF
        destination = "/opt/legion/config/settings.json"
        change_mode = "restart"
      }

      vault {
        policies = ["legionio-api"]
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
