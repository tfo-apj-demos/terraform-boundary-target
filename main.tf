# Local Variables
locals {
  # Check if any service requires a credential path
  services_needing_creds = length(flatten([for service in var.services : service.credential_paths != null ? service.credential_paths : []])) > 0

  # Flattening service credentials for easier iteration
  service_by_credential_path = flatten([for service in var.services : [
    for credential_path in (service.credential_paths != null ? service.credential_paths : []) : {
      name            = service.name,
      type            = service.type,
      port            = service.port,
      credential_path = credential_path
    }]
  ])

  # Services that don't need credential paths
  service_without_creds = [for service in var.services : {
    name = service.name,
    type = service.type,
    port = service.port
  } if service.credential_paths == null]

  # Use the passed existing Vault credential store ID, or fallback to the newly created one, only if credentials are needed
  credential_store_id = local.services_needing_creds ? (var.existing_vault_credential_store_id != "" ? var.existing_vault_credential_store_id : boundary_credential_store_vault.this[0].id) : null
  target_map = {
    for host in var.hosts : host.hostname => {
      # Extract the key from the credential path (last part after "creds/")
      tcp_with_creds_target = try(boundary_target.tcp_with_creds[element(split("/", var.services[0].credential_paths[0]), length(split("/", var.services[0].credential_paths[0])) - 1)].id, null),
      ssh_target            = try(boundary_target.ssh_with_creds[element(split("/", var.services[0].credential_paths[0]), length(split("/", var.services[0].credential_paths[0])) - 1)].id, null)
    }
  }

  host_service_map = {
    for host in var.hosts : host.hostname => var.services[0].name  # Assuming 1-to-1 mapping
  }
  
  services_map = { for service in var.services : service.name => service }
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

# Resources

# Vault credential store for services needing credentials (only if applicable)
resource "boundary_credential_store_vault" "this" {
  count = local.services_needing_creds && var.existing_vault_credential_store_id == "" ? 1 : 0
  name = "Credential Store for ${var.hostname_prefix}"
  scope_id = data.boundary_scope.project.id
  address = var.vault_address
  token = var.credential_store_token
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
  worker_filter   = "\"vmware\" in \"/tags/platform\""
}

# Host catalog for static hosts
resource "boundary_host_catalog_static" "this" {
  name        = "GCVE Host Catalog for ${var.hostname_prefix}"
  description = "Host Catalog ${var.hostname_prefix}"
  scope_id    = data.boundary_scope.project.id
}

# Define static hosts, mapped by hostname
resource "boundary_host_static" "this" {
  for_each        = { for host in var.hosts : host.hostname => host }
  type            = "static"
  name            = each.value.hostname
  host_catalog_id = boundary_host_catalog_static.this.id
  address         = each.value.address
}

# Host set for static hosts, mapping them to the catalog
resource "boundary_host_set_static" "this" {
  type            = "static"
  name            = "${var.hostname_prefix}-servers"
  host_catalog_id = boundary_host_catalog_static.this.id
  host_ids        = [for host in boundary_host_static.this : host.id]
}

# Conditionally create a new Vault credential library for TCP services (excluding SSH)
resource "boundary_credential_library_vault" "this" {
  for_each = {
    for service in local.service_by_credential_path : 
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => service
    if service.type == "tcp" && !contains(keys(var.existing_vault_credential_library_ids), element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1))
  }

  name                = "Credential Library for ${each.value.name}"  # Custom name based on the service name
  path                = each.value.credential_path
  credential_store_id = local.credential_store_id
}

# Conditionally create a new SSH credential library
resource "boundary_credential_library_vault_ssh_certificate" "this" {
  for_each = {
    for service in local.service_by_credential_path : 
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => service
    if service.type == "ssh"
  }

  name                = "SSH Key Signing for ${each.value.name}"  # Custom name based on the service name
  path                = each.value.credential_path
  username            = "ubuntu"
  key_type            = "ed25519"
  credential_store_id = local.credential_store_id
  extensions = {
    permit-pty = ""
  }
}

# Boundary target for SSH services needing credentials
resource "boundary_target" "ssh_with_creds" {
  for_each = { for service in local.service_by_credential_path : 
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => service
    if service.type == "ssh"
  }

  name = "${var.hostname_prefix}"
  type = each.value.type
  default_port = each.value.port
  scope_id = data.boundary_scope.project.id
  host_source_ids = [boundary_host_set_static.this.id]

  # Inject SSH credentials if provided
  injected_application_credential_source_ids = contains(keys(var.existing_ssh_credential_library_ids), each.key) ? [var.existing_ssh_credential_library_ids[each.key]] : null

  ingress_worker_filter = "\"vmware\" in \"/tags/platform\""  # Filter for workers with the "vmware" tag
}

# Boundary target for TCP services with Vault credentials
resource "boundary_target" "tcp_with_creds" {
  for_each = { for service in local.service_by_credential_path :
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => service
    if service.type == "tcp" && length(service.credential_path) > 0
  }

  name = "${var.hostname_prefix}"
  type = each.value.type
  default_port = each.value.port
  scope_id = data.boundary_scope.project.id
  host_source_ids = [boundary_host_set_static.this.id]

  # Broker TCP credentials if provided
  brokered_credential_source_ids = contains(keys(var.existing_vault_credential_library_ids), each.key) ? [var.existing_vault_credential_library_ids[each.key]] : (contains(keys(boundary_credential_library_vault.this), each.key) ? [boundary_credential_library_vault.this[each.key].id] : null)

  ingress_worker_filter = "\"vmware\" in \"/tags/platform\"" # Filter for workers with the "vmware" tag
}

# Boundary alias for TCP services with credentials
resource "boundary_alias_target" "tcp_with_creds_alias" {
  for_each = {
    for host_key, host in boundary_host_static.this : host_key => host
    if local.target_map[host_key].tcp_with_creds_target != null
  }

  name        = "${each.value.name}_tcp_with_creds_alias"
  description = "Alias for ${each.value.name} TCP access with credentials"
  scope_id    = data.boundary_scope.project.id
  value       = local.services_map[local.host_service_map[each.value.name]].alias  # Reference the service name via the host-service map
  destination_id = local.target_map[each.key].tcp_with_creds_target
  authorize_session_host_id = each.value.id
}





# Boundary target for TCP services without Vault credentials (Transparent Sessions where you don't want to broker credentials)
resource "boundary_target" "tcp_without_creds" {
  for_each = { for service in local.service_without_creds :
    service.name => service
  }

  name = "${var.hostname_prefix}"
  type = each.value.type
  default_port = each.value.port
  scope_id = data.boundary_scope.project.id
  host_source_ids = [boundary_host_set_static.this.id]

  ingress_worker_filter = "\"vmware\" in \"/tags/platform\"" # Filter for workers with the "vmware" tag
}