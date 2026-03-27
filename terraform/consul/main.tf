terraform {
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.21"
    }
  }
}

variable "consul_address" {
  type        = string
  description = "Consul HTTP address"
}

variable "consul_token" {
  type        = string
  sensitive   = true
  description = "Consul ACL token with operator privileges"
}

provider "consul" {
  address = var.consul_address
  token   = var.consul_token
}

# partition for LegionIO services
resource "consul_admin_partition" "legionio" {
  name        = "legionio"
  description = "LegionIO service mesh partition"
}

# namespace within the partition
resource "consul_namespace" "default" {
  name        = "default"
  partition   = consul_admin_partition.legionio.name
  description = "Default LegionIO namespace"
}

# service intentions: allow inter-service communication
locals {
  legion_services = [
    "legion-core",
    "legion-cognitive",
    "legion-ai",
    "legion-knowledge",
    "legion-operations",
    "legion-api",
    "legion-teams",
    "legion-slack",
  ]
}

# allow all legion services to talk to each other
resource "consul_config_entry" "allow_legion_mesh" {
  kind = "service-intentions"
  name = "*"

  config_json = jsonencode({
    Sources = [
      for svc in local.legion_services : {
        Name       = svc
        Partition  = consul_admin_partition.legionio.name
        Namespace  = "default"
        Action     = "allow"
        Precedence = 6
      }
    ]
  })
}

# allow legion services to reach infrastructure
resource "consul_config_entry" "allow_infra" {
  for_each = toset(["rabbitmq", "redis", "postgresql"])
  kind     = "service-intentions"
  name     = each.key

  config_json = jsonencode({
    Sources = [
      {
        Name       = "*"
        Partition  = consul_admin_partition.legionio.name
        Namespace  = "default"
        Action     = "allow"
        Precedence = 5
      }
    ]
  })
}

# ACL policy for legion services
resource "consul_acl_policy" "legionio" {
  name        = "legionio-services"
  description = "Policy for LegionIO container services"

  rules = <<-RULE
    service_prefix "legion-" {
      policy = "write"
    }
    node_prefix "" {
      policy = "read"
    }
    key_prefix "legionio/" {
      policy = "write"
    }
    session_prefix "" {
      policy = "write"
    }
  RULE
}

# ACL token for legion services
resource "consul_acl_token" "legionio" {
  description = "LegionIO service token"
  policies    = [consul_acl_policy.legionio.name]
}
