packer {
  required_plugins {
    docker = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "base_image" {
  type        = string
  default     = "ghcr.io/legionio/legion-base:latest"
  description = "Base image to build on"
}

variable "version" {
  type        = string
  default     = "latest"
  description = "Image tag version"
}

variable "registry_ghcr" {
  type        = string
  default     = "ghcr.io/legionio"
  description = "GHCR registry prefix"
}

variable "registry_docker" {
  type        = string
  default     = "docker.io/legionio"
  description = "Docker Hub registry prefix"
}

locals {
  image_name = "legion-core"

  # extensions included in the core role profile
  core_extensions = [
    "lex-codegen",
    "lex-conditioner",
    "lex-exec",
    "lex-health",
    "lex-lex",
    "lex-llm-gateway",
    "lex-log",
    "lex-metering",
    "lex-node",
    "lex-ping",
    "lex-scheduler",
    "lex-tasker",
    "lex-task_pruner",
    "lex-telemetry",
    "lex-transformer",
  ]
}

source "docker" "core" {
  image  = var.base_image
  commit = true
  changes = [
    "ENV LEGION_ROLE_PROFILE=core",
    "ENV LEGION_PROCESS_ROLE=worker",
    "HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -sf http://localhost:4567/health || exit 1",
  ]
}

build {
  sources = ["source.docker.core"]

  # install core extensions
  provisioner "shell" {
    environment_vars = [
      "GEM_HOME=/opt/legion/gems",
      "PATH=/opt/legion/gems/bin:/usr/local/bundle/bin:/usr/local/bin:/usr/bin:/bin",
    ]
    inline = [
      "gem install --no-document ${join(" ", local.core_extensions)}",
      "chown -R legion:legion /opt/legion/gems",
    ]
  }

  # default settings for core role
  provisioner "file" {
    source      = "${path.root}/settings.json"
    destination = "/opt/legion/config/settings.json"
  }

  provisioner "shell" {
    inline = [
      "chown legion:legion /opt/legion/config/settings.json",
    ]
  }

  # push to ghcr
  post-processors {
    post-processor "docker-tag" {
      repository = "${var.registry_ghcr}/${local.image_name}"
      tags       = [var.version, "latest"]
    }

    post-processor "docker-push" {
      login_server = "ghcr.io"
    }
  }

  # push to docker hub
  post-processors {
    post-processor "docker-tag" {
      repository = "${var.registry_docker}/${local.image_name}"
      tags       = [var.version, "latest"]
    }

    post-processor "docker-push" {}
  }
}
