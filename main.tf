# Local values for credential configuration based on inputs
locals {
  use_vault_creds     = var.credential_source == "vault" && var.use_credentials
  credential_store_id = var.existing_credential_store_id != null ? var.existing_credential_store_id : (length(boundary_credential_store_vault.this) > 0 ? boundary_credential_store_vault.this[0].id : null)
}

# Data Sources to get the organizational and project scopes
data "boundary_scope" "org" {
  scope_id = "global"
  name     = "tfo_apj_demos"
}

data "boundary_scope" "project" {
  scope_id = data.boundary_scope.org.id
  name     = var.project_name
}

# Boundary static host catalog
resource "boundary_host_catalog_static" "this" {
  name        = "${var.target_name} Host Catalog"
  description = "Host Catalog for ${var.target_name}"
  scope_id    = data.boundary_scope.project.id
}

# Define hosts based on provided host list
resource "boundary_host_static" "this" {
  for_each        = toset(var.hosts)
  type            = "static"
  name            = each.key
  host_catalog_id = boundary_host_catalog_static.this.id
  address         = each.key
}

# Host set that includes all specified hosts, even if it's a single host
resource "boundary_host_set_static" "this" {
  type            = "static"
  name            = "${var.target_name} Host Set"
  description     = "Host Set for ${var.target_name}"
  host_catalog_id = boundary_host_catalog_static.this.id
  host_ids        = [for host in boundary_host_static.this : host.id]
}

# Vault credential store
resource "boundary_credential_store_vault" "this" {
  count         = local.use_vault_creds && var.existing_credential_store_id == null ? 1 : 0
  name          = "${var.target_name} Credential Store"
  scope_id      = data.boundary_scope.project.id
  address       = var.vault_address
  token         = var.credential_store_token
  namespace     = var.vault_namespace != "" ? var.vault_namespace : null
  worker_filter = "\"vmware\" in \"/tags/platform\""

  # Ignore changes to the worker_filter attribute to avoid unnecessary updates. This may be a bug in the provider.
  lifecycle {
    ignore_changes = [worker_filter]
  }
}

# Conditional TCP or SSH Vault Credential Library
resource "boundary_credential_library_vault" "tcp" {
  for_each = { for host in var.hosts : host => host if var.target_type == "tcp" && local.use_vault_creds }

  name                = "${var.target_name} TCP Vault Credential Library ${each.key}"
  description         = "Vault TCP Credential Library for ${each.key}"
  credential_store_id = local.credential_store_id
  path                = var.credential_path
  http_method         = "GET"
}

resource "boundary_credential_library_vault_ssh_certificate" "ssh" {
  for_each = { for host in var.hosts : host => host if var.target_type == "ssh" && local.use_vault_creds }

  name                = "${var.target_name} SSH Cert Library ${each.key}"
  description         = "SSH Vault Credential Library for ${each.key}"
  credential_store_id = local.credential_store_id
  path                = var.credential_path
  username            = "ubuntu"
  key_type            = "ed25519"
  extensions          = { permit-pty = "" }
}

# Boundary Target for TCP or SSH, referencing the host set
resource "boundary_target" "this" {
  name            = "${var.target_name} Target"
  description     = "Boundary target for ${var.target_name}"
  type            = var.target_type
  default_port    = var.port
  scope_id        = data.boundary_scope.project.id
  host_source_ids = [boundary_host_set_static.this.id] # References the host set, even if it's one host

  # Define credential source IDs for SSH, conditional on target mode and credential source
  injected_application_credential_source_ids = (
    # SINGLE TARGET MODE LOGIC
    var.target_type == "ssh" && var.target_mode == "single"
    ) ? (
    # If using Vault-managed credentials in single mode
    local.use_vault_creds ?
    # Attempt to look up Vault-managed SSH credential library for the first host
    compact([lookup(boundary_credential_library_vault_ssh_certificate.ssh, var.hosts[0], "").id]) :
    # Else, use existing SSH credentials for the first host if Module creation is not being used
    compact([lookup(var.existing_ssh_credential_libraries, var.hosts[0], null)])
    ) : (
    # GROUP TARGET MODE LOGIC
    var.target_type == "ssh" && var.target_mode == "group" ?
    # Iterate over each host in group mode to inject SSH credentials
    compact([for host in var.hosts : local.use_vault_creds ?
      # Use Vault-managed SSH credentials for each host in the group if Vault credentials are enabled
      lookup(boundary_credential_library_vault_ssh_certificate.ssh, host, null) :
      # Otherwise, use existing SSH credentials if Module credentials are not being used
      lookup(var.existing_ssh_credential_libraries, host, null)
      # Fallback to null if neither single nor group mode is specified for SSH
    ]) : null
  )


  brokered_credential_source_ids = (
    local.use_vault_creds && var.target_type == "tcp" && var.target_mode == "single"
  ) ? compact([lookup(boundary_credential_library_vault.tcp, var.hosts[0], "").id]) : null

  ingress_worker_filter = "\"vmware\" in \"/tags/platform\""
}

# Boundary Target Alias
resource "boundary_alias_target" "alias" {
  count                    = var.alias_name != "" ? 1 : 0  # Create only if `alias_name` is set
  name                     = var.alias_name
  value                    = var.alias_name
  scope_id                 = "global"
  destination_id           = boundary_target.this.id
  authorize_session_host_id = element([for host in boundary_host_static.this : host.id], 0)
}