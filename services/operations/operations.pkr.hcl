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

variable "registry" {
  type        = string
  default     = "ghcr.io/legionio"
  description = "Container registry prefix"
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
      "PATH=/opt/legion/gems/bin:/usr/local/bundle/bin:/usr/local/bin:/usr/bin:/bin",
    ]
    inline = [
      "gem install --no-document ${join(" ", local.operations_extensions)}",
      "chown -R legion:legion /opt/legion/gems",
    ]
  }

  provisioner "file" {
    source      = "${path.root}/settings.json"
    destination = "/etc/legionio/settings/settings.json"
  }

  provisioner "shell" {
    inline = [
      "chown legion:legion /etc/legionio/settings/settings.json",
    ]
  }

  # tag for docker hub (workflow handles push to both registries)
  post-processor "docker-tag" {
    repository = "${var.registry}/${local.image_name}"
    tags       = [var.version, "latest"]
  }
}
