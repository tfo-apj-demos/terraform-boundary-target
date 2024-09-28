locals {
  # Check if any service needs credentials
  services_needing_creds = length(flatten([for service in var.services : lookup(service, "use_existing_creds", false) || lookup(service, "use_vault_creds", false) ? [service] : []])) > 0

  # Process services to ensure that only one credential source is used
  # Process services uniformly for all hosts, without indexing into var.services
  processed_services = [
    for host in var.hosts : {
      fqdn               = host.fqdn
      type               = var.services[0].type
      port               = var.services[0].port
      use_existing_creds = var.services[0].use_existing_creds
      use_vault_creds    = var.services[0].use_vault_creds
      credential_source  = var.services[0].use_existing_creds ? "existing" : (var.services[0].use_vault_creds ? "vault" : null)

      # Provide default path for SSH, but require user-specified path for others if using vault creds
      credential_path = var.services[0].type == "ssh" && var.services[0].use_vault_creds ? coalesce(var.services[0].credential_path, "ssh/sign/boundary") : (var.services[0].use_vault_creds ? var.services[0].credential_path : null)
    }
  ]

  # Map hostname to processed service object
  hostname_to_service_map = {
    for host in var.hosts : host.fqdn => local.processed_services[0]
  }

  # Map of TCP credential library IDs, merging existing or newly created
  tcp_credential_library_ids = merge(
    lookup(var.existing_infrastructure, "tcp_credential_libraries", {}),
    { for service in local.processed_services : service.fqdn => boundary_credential_library_vault.tcp[service.fqdn].id
    if service.type == "tcp" && service.use_vault_creds }
  )

  # Map of SSH credential library IDs, merging existing or newly created
  ssh_credential_library_ids = merge(
    lookup(var.existing_infrastructure, "ssh_credential_libraries", {}),
    { for service in local.processed_services : service.fqdn => boundary_credential_library_vault_ssh_certificate.ssh[service.fqdn].id
    if service.type == "ssh" && service.use_vault_creds }
  )
}