# Local Variables
locals {
  # Check if any service requires a credential path
  services_needing_creds = length(flatten([for service in var.services : service.credential_paths != null ? service.credential_paths : []])) > 0

  # Flattening service credentials for easier iteration
  service_by_credential_path = flatten([for service in var.services : [
    for credential_path in (service.credential_paths != null ? service.credential_paths : []) : {
      name            = service.name,
      type            = service.type,
      port            = service.port
      credential_path = credential_path
    }]
  ])

  # Services that don't need credential paths
  service_without_creds = [for service in var.services : {
    name = service.name
    type = service.type
    port = service.port
  } if service.credential_paths == null]

  # Use the passed existing Vault credential store ID, or fallback to the newly created one, only if credentials are needed
  credential_store_id = local.services_needing_creds ? (var.existing_vault_credential_store_id != "" ? var.existing_vault_credential_store_id : boundary_credential_store_vault.this[0].id) : null
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

# Conditionally create the Vault credential store only if it doesn’t exist and credentials are needed
resource "boundary_credential_store_vault" "this" {
  count           = local.services_needing_creds && var.existing_vault_credential_store_id == "" ? 1 : 0
  
  scope_id        = data.boundary_scope.project.id
  name            = "Credential Store for ${var.hostname_prefix}"
  
  address         = var.vault_address
  token           = var.credential_store_token
  namespace       = var.vault_namespace != "" ? var.vault_namespace : null
  tls_skip_verify = var.tls_skip_verify_vault_server
  ca_cert         = var.vault_ca_cert != "" ? var.vault_ca_cert : null

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

# Conditionally create a new Vault credential library for TCP services
resource "boundary_credential_library_vault" "this" {
  for_each = { for service in local.service_by_credential_path :
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => service
    if service.type == "tcp" && !contains(keys(var.existing_vault_credential_library_ids), service.name)
  }

  name                = "Credential Library for ${each.value.name}"  # Custom name based on the service name
  path                = each.value.credential_path
  credential_store_id = local.credential_store_id
}

# Conditionally create a new SSH credential library
resource "boundary_credential_library_vault_ssh_certificate" "this" {
  for_each = { for service in local.service_by_credential_path :
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => service
    if service.type == "ssh" && !contains(keys(var.existing_ssh_credential_library_ids), element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1))
  }

  name                = "SSH Key Signing"
  path                = each.value.credential_path
  username            = "ubuntu"
  key_type            = "ed25519"
  credential_store_id = local.credential_store_id
  extensions = {
    permit-pty = ""
  }
}

# Boundary target definition that handles both services with and without credentials
resource "boundary_target" "this" {
  for_each = merge(
    { for service in local.service_by_credential_path : 
      element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => service
    },
    { for service in local.service_without_creds : 
      service.name => service 
    }
  )

  name         = "${var.hostname_prefix}_Access"
  type         = each.value.type
  default_port = each.value.port
  scope_id     = data.boundary_scope.project.id

  host_source_ids = [boundary_host_set_static.this.id]

  # Conditional logic to handle credentials based on service type and if required
  injected_application_credential_source_ids = (
    each.value.type == "ssh" ? 
      [lookup(var.existing_ssh_credential_library_ids, each.key, boundary_credential_library_vault_ssh_certificate[each.key].id)] :
    (each.value.type == "rdp" || each.value.type == "tcp") && lookup(each.value, "credential_path", null) != null ? 
      (
        contains(keys(var.existing_vault_credential_library_ids), each.key) ? 
          [var.existing_vault_credential_library_ids[each.key]] : 
          [boundary_credential_library_vault[each.key].id]
      ) :
    null
  )

  ingress_worker_filter = "\"vmware\" in \"/tags/platform\""
}

