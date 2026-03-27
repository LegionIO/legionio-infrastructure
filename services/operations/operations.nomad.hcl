variable "image" {
  type        = string
  default     = "ghcr.io/legionio/legion-operations:latest"
  description = "Container image for legion-operations"
}

variable "count" {
  type        = number
  default     = 1
  description = "Number of operations worker instances"
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

job "legion-operations" {
  datacenters = ["dc1"]
  type        = "service"

  group "operations" {
    count = var.count

    network {
      port "health" {
        to = 4567
      }
    }

    service {
      name = "legion-operations"
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

    task "operations" {
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
              "autofix", "swarm-github", "mind-growth", "pilot-infra-monitor",
              "cost-scanner", "onboard", "eval", "factory", "github", "slack"
            ]
          },
          "transport": { "url": "${var.rabbitmq_url}", "vhost": "legionio" },
          "cache": { "driver": "redis", "url": "${var.redis_url}" },
          "data": { "adapter": "postgres", "host": "${var.postgres_host}", "port": 5432, "database": "legionio", "pool_size": 10 },
          "logging": { "level": "info", "json": true },
          "vault": { "address": "${var.vault_addr}", "namespace": "legionio" },
          "api": { "enabled": false }
        }
        EOF
        destination = "/opt/legion/config/settings.json"
        change_mode = "restart"
      }

      vault {
        policies = ["legionio-operations"]
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
