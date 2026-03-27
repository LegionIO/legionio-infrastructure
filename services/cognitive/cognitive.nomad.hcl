variable "image" {
  type        = string
  default     = "ghcr.io/legionio/legion-cognitive:latest"
  description = "Container image for legion-cognitive"
}

variable "count" {
  type        = number
  default     = 2
  description = "Number of cognitive worker instances"
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

job "legion-cognitive" {
  datacenters = ["dc1"]
  type        = "service"

  group "cognitive" {
    count = var.count

    network {
      port "health" {
        to = 4567
      }
    }

    service {
      name = "legion-cognitive"
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

    task "cognitive" {
      driver = "docker"

      config {
        image = var.image
        ports = ["health"]
      }

      env {
        LEGION_PROCESS_ROLE = "worker"
        LEGION_ROLE_PROFILE = "cognitive"
      }

      template {
        data        = <<-EOF
        {
          "process": { "role": "worker" },
          "role": { "profile": "cognitive" },
          "transport": { "url": "${var.rabbitmq_url}", "vhost": "legionio" },
          "cache": { "driver": "redis", "url": "${var.redis_url}" },
          "data": { "adapter": "postgres", "host": "${var.postgres_host}", "port": 5432, "database": "legionio", "pool_size": 10 },
          "logging": { "level": "info", "json": true },
          "vault": { "address": "${var.vault_addr}", "namespace": "legionio" },
          "gaia": { "enabled": true },
          "api": { "enabled": false }
        }
        EOF
        destination = "/opt/legion/config/settings.json"
        change_mode = "restart"
      }

      vault {
        policies = ["legionio-cognitive"]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
