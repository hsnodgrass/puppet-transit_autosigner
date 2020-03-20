# Grants access to the encrypt endpoint for our transit encryption
path "transit/encrypt/puppet_autosigner" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}