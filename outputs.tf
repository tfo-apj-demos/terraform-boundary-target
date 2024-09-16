output "existing_ssh_credential_library_ids" {
  value = var.existing_ssh_credential_library_ids
}

output "service_keys" {
  value = [for service in local.service_by_credential_path :
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1)
  ]
}

output "host_catalog_id" {
  description = "The ID of the host catalog, either passed or created."
  value       = var.host_catalog_id != null ? var.host_catalog_id : boundary_host_catalog_static.this.id
}

output "host_ids" {
  value = [for host in boundary_host_static.this : host.id]
}

output "tcp_with_creds_targets" {
  value = boundary_target.tcp_with_creds
}

output "ssh_with_creds_targets" {
  value = boundary_target.ssh_with_creds
}

output "target_map_debug" {
  value = local.target_map
}

output "services_map_debug" {
  value = local.services_map
}

output "host_service_map_debug" {
  value = local.host_service_map
}



