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
  image = "${var.registry}/legion-slack:${var.image_tag}"

  settings = {
    process = { role = "worker" }
    role = {
      profile = "custom"
      extensions = [
        "codegen", "conditioner", "exec", "health", "lex", "llm-gateway",
        "log", "metering", "node", "ping", "scheduler", "tasker",
        "task_pruner", "telemetry", "transformer",
        "slack",
      ]
    }

    crypt = {
      vault = { enabled = false }
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


    slack = { polling_enabled = true }

    extensions = { parallel_pool_size = 4 }
    rbac       = { enabled = false, enforce = false }
    api        = { enabled = true, bind = "0.0.0.0", port = 4567 }
  }
}

variable "count" {
  type        = number
  default     = 1
  description = "Number of Slack integration instances"
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

job "legion-slack" {
  datacenters = ["*"]
  type        = "service"

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }

  group "slack" {
    count = var.count

    reschedule {
      delay          = "5s"
      max_delay      = "10s"
      unlimited      = true
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "15s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      port "health" {
        to = 4567
      }
    }

    service {
      name = "legion-slack"
      port = "health"

      check {
        type     = "http"
        path     = "/api/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    restart {
      attempts = 0
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    task "slack" {
      driver = "docker"

      config {
        image   = local.image
        command = "legionio"
        args    = ["start"]
        volumes    = ["local:/etc/legionio/settings"]
        ports   = ["health"]
      }

      env {
        LEGION_PROCESS_ROLE  = "api"
        LEGION_ROLE_PROFILE  = "custom"
        LEGION_SETTINGS_FILE = "/etc/legionio/settings/settings.json"
      }

      template {
        data        = jsonencode(local.settings)
        destination = "local/settings.json"
        change_mode = "restart"
      }


      resources {
        cpu    = 250
        memory = 256
      }
    }
  }
}
