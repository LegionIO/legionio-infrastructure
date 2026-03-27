# Global connection variables for all LegionIO Nomad jobs.
# Usage: nomad job run -var-file=../../globals.vars.hcl <service>.nomad.hcl

# RabbitMQ
rabbitmq_host     = "rabbitmq.service.consul"
rabbitmq_port     = 5672
rabbitmq_username = "guest"
rabbitmq_password = "guest"
rabbitmq_vhost    = "legionio"

# Redis
redis_host     = "redis.service.consul"
redis_port     = 6379
redis_database = 0
redis_username = ""
redis_password = ""

# PostgreSQL
postgres_host     = "postgresql.service.consul"
postgres_port     = 5432
postgres_username = "legionio"
postgres_password = "legionio"
postgres_database = "legionio"

# Vault
vault_protocol  = "https"
vault_host      = "vault.service.consul"
vault_port      = 8200
vault_addr      = "https://vault.service.consul:8200"
vault_namespace = "legionio"
vault_token     = ""
vault_kv_path      = "kv"
vault_skip_verify  = "false"

# Logging
logging_level = "info"

# Data
data_auto_migrate = true
