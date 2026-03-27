packer {
  required_plugins {
    docker = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "ruby_version" {
  type        = string
  default     = "3.4"
  description = "Ruby minor version to install"
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
  image_name = "legion-base"
}

source "docker" "base" {
  image  = "ruby:${var.ruby_version}-slim"
  commit = true
  changes = [
    "ENV LEGION_HOME=/opt/legion",
    "ENV GEM_HOME=/opt/legion/gems",
    "ENV PATH=/opt/legion/gems/bin:/opt/legion/bin:$PATH",
    "ENV RUBY_YJIT_ENABLE=1",
    "WORKDIR /opt/legion",
    "ENTRYPOINT [\"/opt/legion/bin/entrypoint.sh\"]",
    "CMD [\"legion\", \"start\"]",
  ]
}

build {
  sources = ["source.docker.base"]

  # system deps: build tools, native gem libs, runtime libs
  provisioner "shell" {
    inline = [
      "apt-get update -qq",
      "apt-get install -y --no-install-recommends \\",
      "  build-essential git curl ca-certificates \\",
      "  libpq-dev libsqlite3-dev libffi-dev \\",
      "  libssl-dev libyaml-dev",
      "rm -rf /var/lib/apt/lists/*",
    ]
  }

  # create legion user and directories
  provisioner "shell" {
    inline = [
      "groupadd -r legion",
      "useradd -r -g legion -d /opt/legion -s /bin/bash legion",
      "mkdir -p /opt/legion/{bin,gems,config,data,logs}",
      "mkdir -p /home/legion/.legionio",
      "chown -R legion:legion /opt/legion /home/legion",
    ]
  }

  # install legionio framework + core libraries + su-exec
  provisioner "shell" {
    environment_vars = [
      "GEM_HOME=/opt/legion/gems",
      "PATH=/opt/legion/gems/bin:$PATH",
    ]
    inline = [
      "apt-get update -qq && apt-get install -y --no-install-recommends su-exec && rm -rf /var/lib/apt/lists/*",
      "gem install --no-document legionio",
      "gem install --no-document legion-json legion-logging legion-transport legion-cache legion-data legion-crypt",
      "gem install --no-document lex-node",
      "gem install --no-document pg sqlite3",
      "gem install --no-document bootsnap",
      "bootsnap precompile --gemfile /opt/legion/gems",
      "chown -R legion:legion /opt/legion/gems",
    ]
  }

  # entrypoint script
  provisioner "file" {
    source      = "${path.root}/entrypoint.sh"
    destination = "/opt/legion/bin/entrypoint.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /opt/legion/bin/entrypoint.sh",
      "chown legion:legion /opt/legion/bin/entrypoint.sh",
    ]
  }

  # push to ghcr
  post-processor "docker-tag" {
    repository = "${var.registry_ghcr}/${local.image_name}"
    tags       = [var.version, "latest"]
  }

  post-processor "docker-push" {
    login_server = "ghcr.io"
  }

  # push to docker hub
  post-processor "docker-tag" {
    repository = "${var.registry_docker}/${local.image_name}"
    tags       = [var.version, "latest"]
  }

  post-processor "docker-push" {}
}
