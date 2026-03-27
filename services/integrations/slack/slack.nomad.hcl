variable "image" {
  type        = string
  default     = "ghcr.io/legionio/legion-slack:latest"
  description = "Container image for legion-slack"
}

variable "count" {
  type        = number
  default     = 1
  description = "Number of Slack integration instances"
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

job "legion-slack" {
  datacenters = ["dc1"]
  type        = "service"

  group "slack" {
    count = var.count

    network {
      port "health" {
        to = 4567
      }
    }

    service {
      name = "legion-slack"
      port = "health"

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "slack" {
      driver = "docker"

      config {
        image = var.image
        ports = ["health"]
      }

      env {
        LEGION_PROCESS_ROLE = "worker"
        LEGION_ROLE_PROFILE = "custom"
      }

      template {
        data        = <<-EOF
        {
          "process": { "role": "worker" },
          "role": {
            "profile": "custom",
            "extensions": [
              "codegen", "conditioner", "exec", "health", "lex", "llm-gateway",
              "log", "metering", "node", "ping", "scheduler", "tasker",
              "task_pruner", "telemetry", "transformer",
              "slack"
            ]
          },
          "transport": { "url": "${var.rabbitmq_url}", "vhost": "legionio" },
          "cache": { "driver": "redis", "url": "${var.redis_url}" },
          "data": { "adapter": "postgres", "host": "${var.postgres_host}", "port": 5432, "database": "legionio", "pool_size": 5 },
          "logging": { "level": "info", "json": true },
          "vault": { "address": "${var.vault_addr}", "namespace": "legionio" },
          "slack": { "polling_enabled": true },
          "api": { "enabled": false }
        }
        EOF
        destination = "/opt/legion/config/settings.json"
        change_mode = "restart"
      }

      vault {
        policies = ["legionio-slack"]
      }

      resources {
        cpu    = 250
        memory = 256
      }
    }
  }
}
