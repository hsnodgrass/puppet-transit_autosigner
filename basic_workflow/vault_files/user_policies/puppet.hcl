# Grants access to the decrypt endpoint for our transit encryption
path "transit/decrypt/puppet_autosigner" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}