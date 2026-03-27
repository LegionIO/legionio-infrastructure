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
  default     = "ghcr.io/legionio/legion-core:latest"
  description = "Core image to build on"
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
  image_name = "legion-operations"

  operations_extensions = [
    "lex-autofix",
    "lex-swarm-github",
    "lex-mind-growth",
    "lex-pilot-infra-monitor",
    "lex-cost-scanner",
    "lex-onboard",
    "lex-codegen",
    "lex-eval",
    "lex-factory",
    "lex-github",
    "lex-slack",
  ]
}

source "docker" "operations" {
  image  = var.base_image
  commit = true
  changes = [
    "ENV LEGION_ROLE_PROFILE=custom",
    "ENV LEGION_PROCESS_ROLE=worker",
    "HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -sf http://localhost:4567/health || exit 1",
  ]
}

build {
  sources = ["source.docker.operations"]

  provisioner "shell" {
    environment_vars = [
      "GEM_HOME=/opt/legion/gems",
      "PATH=/opt/legion/gems/bin:$PATH",
    ]
    inline = [
      "gem install --no-document ${join(" ", local.operations_extensions)}",
      "bootsnap precompile --gemfile /opt/legion/gems",
      "chown -R legion:legion /opt/legion/gems",
    ]
  }

  provisioner "file" {
    source      = "${path.root}/settings.json"
    destination = "/opt/legion/config/settings.json"
  }

  provisioner "shell" {
    inline = [
      "chown legion:legion /opt/legion/config/settings.json",
    ]
  }

  post-processor "docker-tag" {
    repository = "${var.registry_ghcr}/${local.image_name}"
    tags       = [var.version, "latest"]
  }

  post-processor "docker-push" {
    login_server = "ghcr.io"
  }

  post-processor "docker-tag" {
    repository = "${var.registry_docker}/${local.image_name}"
    tags       = [var.version, "latest"]
  }

  post-processor "docker-push" {}
}
