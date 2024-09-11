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