locals {
  # Map destination IDs using host names
  destination_ids = merge(
    { for host in var.hosts : host.fqdn => boundary_target.tcp_with_creds[host.fqdn].id if contains(keys(boundary_target.tcp_with_creds), host.fqdn) },
    { for i in range(length(var.hosts)) : var.hosts[i].fqdn => boundary_target.ssh_with_creds[i].id if boundary_target.ssh_with_creds[i].id != null }
  )
}

# Boundary target for SSH services
resource "boundary_target" "ssh_with_creds" {
  count = length(var.hosts) > 0 ? length(var.hosts) : 0

  name            = var.hostname_prefix
  type            = var.services[0].type
  default_port    = var.services[0].port
  scope_id        = data.boundary_scope.project.id
  host_source_ids = [boundary_host_set_static.this.id]

  # Inject SSH credentials if provided
  injected_application_credential_source_ids = contains(keys(var.existing_infrastructure.ssh_credential_libraries), var.hosts[count.index].fqdn) ? [lookup(var.existing_infrastructure.ssh_credential_libraries, var.hosts[count.index].fqdn, null)] : (var.services[0].use_vault_creds ? [lookup(local.ssh_credential_library_ids, var.hosts[count.index].fqdn, null)] : null)

  ingress_worker_filter = "\"vmware\" in \"/tags/platform\"" # Filter for workers with the "vmware" tag
}

# Boundary target for TCP services
resource "boundary_target" "tcp_with_creds" {
  for_each = { for host in var.hosts : host.fqdn => host if var.services[0].type == "tcp" }

  name                = var.hostname_prefix
  type                = var.services[0].type
  default_port        = var.services[0].port
  default_client_port = var.services[0].port
  scope_id            = data.boundary_scope.project.id
  host_source_ids     = [boundary_host_set_static.this.id]

  # Broker TCP credentials if provided
  brokered_credential_source_ids = local.hostname_to_service_map[each.key].use_vault_creds ? [local.tcp_credential_library_ids[each.key]] : null
  ingress_worker_filter          = "\"vmware\" in \"/tags/platform\"" # Filter for workers with the "vmware" tag
}

# Boundary alias for TCP and SSH services
resource "boundary_alias_target" "target_alias" {
  for_each = boundary_host_static.this

  name        = each.value.name
  description = "Alias for ${each.value.name} access"
  scope_id    = "global"

  # Use the address from the hosts input as the alias value
  value = lookup({ for host in var.hosts : host.fqdn => host.fqdn }, each.value.name, null)

  destination_id            = local.destination_ids[each.value.name] # Refer to the correct destination ID
  authorize_session_host_id = each.value.id
}