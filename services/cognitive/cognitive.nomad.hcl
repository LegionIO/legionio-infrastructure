variable "registry" {
  type        = string
  default     = "ghcr.io/legionio"
  description = "Container registry prefix"
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Image tag to deploy"
}

locals {
  image = "${var.registry}/legion-cognitive:${var.image_tag}"

  settings = {
    process = { role = "worker" }
    role    = { profile = "cognitive" }

    crypt = {
      cluster_secret = "vault://${var.vault_kv_path}/data/legionio/crypt#cluster_secret"
      vault = {
        enabled             = true
        kv_path             = var.vault_kv_path
        renewer             = true
        renewer_time        = 5
        push_cluster_secret = false
        read_cluster_secret = false
        leases = {
          rabbitmq   = { path = "rabbitmq/creds/agent" }
          postgresql = { path = "postgresql/creds/agent" }
          redis      = { path = "redis/creds/agent" }
        }
      }
    }

    transport = {
      type         = "rabbitmq"
      logger_level = "warn"
      connection = {
        host     = var.rabbitmq_host
        port     = var.rabbitmq_port
        vhost    = var.rabbitmq_vhost
        user     = var.rabbitmq_username
        password = var.rabbitmq_password
      }
    }

    cache = {
      driver   = "redis"
      servers  = ["${var.redis_host}:${var.redis_port}"]
      database = var.redis_database
      username = var.redis_username
      password = var.redis_password
      enabled  = true
    }

    data = {
      adapter          = "postgres"
      connect_on_start = true
      dev_mode         = false
      dev_fallback     = false
      creds = {
        host     = var.postgres_host
        port     = var.postgres_port
        database = var.postgres_database
        user     = var.postgres_username
        password = var.postgres_password
      }
      migrations = {
        auto_migrate     = var.data_auto_migrate
        continue_on_fail = false
      }
    }

    logging = {
      level = var.logging_level
      json  = true
    }

    vault = {
      address   = var.vault_addr
      namespace = var.vault_namespace
      token     = var.vault_token
    }

    llm = {
      enabled          = true
      pipeline_enabled = true
      default_provider = "bedrock"
      default_model    = "us.anthropic.claude-sonnet-4-6"
      providers = {
        bedrock = {
          enabled       = true
          region        = "us-east-2"
          bearer_token  = "vault://${var.vault_kv_path}/data/legionio/llm#bedrock_bearer_token"
          default_model = "us.anthropic.claude-opus-4-6-v1"
          small_model   = "us.anthropic.claude-sonnet-4-6"
          medium_model  = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
        }
      }
      routing = { use_fleet = false }
    }

    extensions = { parallel_pool_size = 4 }
    rbac       = { enabled = false, enforce = false }
    gaia       = { enabled = true }
    api        = { enabled = false }
  }
}

variable "count" {
  type        = number
  default     = 2
  description = "Number of cognitive worker instances"
}

variable "rabbitmq_host" {
  type        = string
  default     = "rabbitmq.service.consul"
  description = "RabbitMQ host"
}

variable "rabbitmq_port" {
  type        = number
  default     = 5672
  description = "RabbitMQ port"
}

variable "rabbitmq_username" {
  type        = string
  default     = "guest"
  description = "RabbitMQ username"
}

variable "rabbitmq_password" {
  type        = string
  default     = "guest"
  description = "RabbitMQ password"
}

variable "rabbitmq_vhost" {
  type        = string
  default     = "legionio"
  description = "RabbitMQ vhost"
}

variable "redis_host" {
  type        = string
  default     = "redis.service.consul"
  description = "Redis host"
}

variable "redis_port" {
  type        = number
  default     = 6379
  description = "Redis port"
}

variable "redis_database" {
  type        = number
  default     = 0
  description = "Redis database number"
}

variable "redis_username" {
  type        = string
  default     = ""
  description = "Redis username"
}

variable "redis_password" {
  type        = string
  default     = ""
  description = "Redis password"
}

variable "postgres_host" {
  type        = string
  default     = "postgresql.service.consul"
  description = "PostgreSQL host"
}

variable "postgres_port" {
  type        = number
  default     = 5432
  description = "PostgreSQL port"
}

variable "postgres_username" {
  type        = string
  default     = "legionio"
  description = "PostgreSQL username"
}

variable "postgres_password" {
  type        = string
  default     = "legionio"
  description = "PostgreSQL password"
}

variable "postgres_database" {
  type        = string
  default     = "legionio"
  description = "PostgreSQL database name"
}

variable "vault_addr" {
  type        = string
  default     = "https://vault.service.consul:8200"
  description = "Vault server address"
}

variable "vault_namespace" {
  type        = string
  default     = "legionio"
  description = "Vault namespace"
}

variable "vault_token" {
  type        = string
  default     = ""
  description = "Vault token for authentication"
}

variable "vault_kv_path" {
  type        = string
  default     = "kv"
  description = "Vault KV secret engine path"
}

variable "logging_level" {
  type        = string
  default     = "info"
  description = "Log level (debug, info, warn, error)"
}

variable "data_auto_migrate" {
  type        = bool
  default     = true
  description = "Run database migrations on start"
}

job "legion-cognitive" {
  datacenters = ["*"]
  type        = "service"

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }

  group "cognitive" {
    count = var.count

    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "5m"
      unlimited      = true
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "15s"
      healthy_deadline = "5m"
    }

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
        image   = local.image
        command = "legionio"
        args    = ["start"]
        volumes    = ["local:/etc/legionio/settings"]
        ports   = ["health"]
      }

      env {
        LEGION_PROCESS_ROLE  = "worker"
        LEGION_ROLE_PROFILE  = "cognitive"
        LEGION_SETTINGS_FILE = "/etc/legionio/settings/settings.json"
        VAULT_ADDR           = var.vault_addr
        VAULT_NAMESPACE      = var.vault_namespace
        VAULT_TOKEN          = var.vault_token
      }

      template {
        data        = jsonencode(local.settings)
        destination = "local/settings.json"
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
