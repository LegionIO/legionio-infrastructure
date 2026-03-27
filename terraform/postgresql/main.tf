terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
  }
}

variable "pg_host" {
  type        = string
  description = "PostgreSQL server host"
}

variable "pg_port" {
  type        = number
  default     = 5432
  description = "PostgreSQL server port"
}

variable "pg_superuser" {
  type        = string
  default     = "postgres"
  description = "PostgreSQL superuser"
}

variable "pg_superuser_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL superuser password"
}

variable "pg_sslmode" {
  type        = string
  default     = "require"
  description = "PostgreSQL SSL mode"
}

provider "postgresql" {
  host     = var.pg_host
  port     = var.pg_port
  username = var.pg_superuser
  password = var.pg_superuser_password
  sslmode  = var.pg_sslmode
}

# main LegionIO database
resource "postgresql_database" "legionio" {
  name              = "legionio"
  owner             = postgresql_role.legionio_admin.name
  encoding          = "UTF8"
  lc_collate        = "en_US.UTF-8"
  lc_ctype          = "en_US.UTF-8"
  connection_limit  = -1
  allow_connections = true
}

# Apollo knowledge store database
resource "postgresql_database" "apollo" {
  name              = "legionio_apollo"
  owner             = postgresql_role.legionio_admin.name
  encoding          = "UTF8"
  lc_collate        = "en_US.UTF-8"
  lc_ctype          = "en_US.UTF-8"
  connection_limit  = -1
  allow_connections = true
}

# admin role (owns databases, manages schema)
resource "postgresql_role" "legionio_admin" {
  name     = "legionio_admin"
  login    = true
  password = "changeme-use-vault-dynamic-creds"

  create_database = false
  create_role     = false
  superuser       = false
}

# application role (used by services via Vault dynamic creds)
resource "postgresql_role" "legionio_app" {
  name     = "legionio_app"
  login    = true
  password = "changeme-use-vault-dynamic-creds"

  create_database = false
  create_role     = false
  superuser       = false
}

# enable pgvector extension for Apollo embeddings
resource "postgresql_extension" "vector" {
  name     = "vector"
  database = postgresql_database.apollo.name
}

# enable pg_trgm for fuzzy text search
resource "postgresql_extension" "pg_trgm" {
  name     = "pg_trgm"
  database = postgresql_database.legionio.name
}

# grant app role access to both databases
resource "postgresql_grant" "app_legionio" {
  database    = postgresql_database.legionio.name
  role        = postgresql_role.legionio_app.name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}

resource "postgresql_grant" "app_apollo" {
  database    = postgresql_database.apollo.name
  role        = postgresql_role.legionio_app.name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}

resource "postgresql_default_privileges" "app_tables" {
  database = postgresql_database.legionio.name
  role     = postgresql_role.legionio_app.name
  owner    = postgresql_role.legionio_admin.name
  schema   = "public"

  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}

resource "postgresql_default_privileges" "app_sequences" {
  database = postgresql_database.legionio.name
  role     = postgresql_role.legionio_app.name
  owner    = postgresql_role.legionio_admin.name
  schema   = "public"

  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
}
