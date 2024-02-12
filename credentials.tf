resource "vault_token" "this" {
  period = 7200
  renewable = true
  no_parent = true
  policies = [
    "default",
    "sign_ssh_certificate",
    "revoke_lease"
  ]
  lifecycle {
    ignore_changes = all 
  }
}

resource "boundary_credential_store_vault" "this" {
    name        = "HCP Vault"
  address     = var.vault_address
  token       = vault_token.this.client_token
  namespace   = "admin/tfo-apj-demos"
  scope_id    = data.boundary_scope.project.id
}

resource "boundary_credential_library_vault" "ldap_creds" {
  count               = var.ldap_credential_library ? 1 : 0
  name                = "ldap_creds"
  description         = "Dynamic LDAP credentials"
  credential_store_id = boundary_credential_store_vault.this.id
  path                = "ldap/creds/vault_ldap_dynamic_demo_role"
  http_method         = "GET"
}