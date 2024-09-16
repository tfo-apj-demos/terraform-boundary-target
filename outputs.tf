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

output "ssh_credential_library_ids" {
  description = "SSH credential library IDs (existing or newly created)"
  value       = local.ssh_credential_library_ids
}

output "new_ssh_credential_library_ids" {
  description = "Newly created SSH credential library IDs"
  value = {
    for service in local.service_by_credential_path : 
    element(split("/", service.credential_path), length(split("/", service.credential_path)) - 1) => boundary_credential_library_vault_ssh_certificate.this[service.name].id
    if service.type == "ssh"
  }
}

output "existing_ssh_credential_library_ids" {
  description = "Existing SSH credential library IDs"
  value       = var.existing_ssh_credential_library_ids
}

output "injected_ssh_credentials" {
  description = "Injected SSH credentials for Boundary targets"
  value = {
    for target_key, target in boundary_target.ssh_with_creds : target_key => target.injected_application_credential_source_ids
  }
}

