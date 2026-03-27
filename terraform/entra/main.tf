terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "teams_redirect_uri" {
  type        = string
  default     = "https://legion-api.service.consul/auth/teams/callback"
  description = "OAuth redirect URI for Teams integration"
}

provider "azuread" {
  tenant_id = var.tenant_id
}

data "azuread_client_config" "current" {}

# LegionIO application registration
resource "azuread_application" "legionio" {
  display_name = "LegionIO"
  owners       = [data.azuread_client_config.current.object_id]

  sign_in_audience = "AzureADMyOrg"

  api {
    requested_access_token_version = 2
  }

  # Microsoft Graph delegated permissions for Teams
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    # Chat.Read — read user chat messages
    resource_access {
      id   = "f501c180-9344-11e6-a5a7-0002a5d5c51b"
      type = "Scope"
    }

    # Chat.ReadWrite — send messages
    resource_access {
      id   = "9ff7295e-131b-4d94-90e1-69fde507ac11"
      type = "Scope"
    }

    # User.Read — sign in and read user profile
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }

    # ChannelMessage.Read.All — read channel messages (application)
    resource_access {
      id   = "7b2449af-6ccd-4f4d-9f78-e550c193f0d2"
      type = "Role"
    }

    # ChannelMessage.Send — send channel messages (delegated)
    resource_access {
      id   = "ebf0f66e-9fb1-49e4-a278-222f76911cf4"
      type = "Scope"
    }
  }

  web {
    redirect_uris = [var.teams_redirect_uri]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }
}

# service principal
resource "azuread_service_principal" "legionio" {
  client_id = azuread_application.legionio.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# client secret (rotate via Vault or manually)
resource "azuread_application_password" "legionio" {
  application_id    = azuread_application.legionio.id
  display_name      = "legionio-service"
  end_date_relative = "8760h" # 1 year
}

output "client_id" {
  value       = azuread_application.legionio.client_id
  description = "Application (client) ID for LegionIO"
}

output "tenant_id" {
  value       = var.tenant_id
  description = "Azure AD tenant ID"
}

output "client_secret" {
  value       = azuread_application_password.legionio.value
  sensitive   = true
  description = "Client secret — store in Vault, do not expose"
}
