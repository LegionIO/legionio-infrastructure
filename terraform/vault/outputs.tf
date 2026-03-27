output "kv_path" {
  value       = vault_mount.kv.path
  description = "KV v2 mount path"
}

output "transit_key" {
  value       = vault_transit_secret_backend_key.data.name
  description = "Transit encryption key name"
}

output "pki_role" {
  value       = vault_pki_secret_backend_role.internal.name
  description = "PKI role for mTLS cert issuance"
}

output "policies" {
  value       = { for k, v in vault_policy.services : k => v.name }
  description = "Vault policy names per service role"
}
