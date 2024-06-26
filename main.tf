locals {
  service_by_credential_path = flatten([ for service in var.services: [
      for credential_path in service.credential_paths: {
        name = service.name,
        type = service.type,
        port = service.port
        credential_path = credential_path
      }]
  ])
}

data "boundary_scope" "org" {
  scope_id = "global"
  name = "tfo_apj_demos"
}

data "boundary_scope" "project" {
  scope_id = data.boundary_scope.org.id
  name = var.project_name
}

resource "boundary_host_static" "this" {
  for_each = { for host in var.hosts: host.hostname => host }
  type            = "static"
  name            = each.value.hostname
  host_catalog_id = var.host_catalog_id
  address         = each.value.address
}

resource "boundary_host_set_static" "this" {
  type            = "static"
  name            = "${var.hostname_prefix}-servers"
  host_catalog_id = var.host_catalog_id

  host_ids = [ for v in boundary_host_static.this: v.id ]

}

resource "boundary_target" "this" {
  for_each = { for service in local.service_by_credential_path: element(split("/", service.credential_path), length(split("/", service.credential_path))-1) => service }
  name         = "${each.key}-${var.hostname_prefix}"
  type         = each.value.type
  default_port = each.value.port
  scope_id     = data.boundary_scope.project.id
  
  host_source_ids = [
    boundary_host_set_static.this.id
  ]

  brokered_credential_source_ids = each.value.type == "tcp" ? [
    boundary_credential_library_vault.this[each.key].id
  ] : null
  injected_application_credential_source_ids = each.value.type == "ssh" ? [
    boundary_credential_library_vault_ssh_certificate.this[each.key].id 
  ] : null
  
  ingress_worker_filter = "\"vmware\" in \"/tags/platform\""
}

resource "boundary_credential_store_vault" "this" {
  name = var.boundary_credential_store_vault_name
  token = var.credential_store_token
  scope_id = data.boundary_scope.project.id
  address = var.vault_address
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
  worker_filter = "\"vmware\" in \"/tags/platform\""
  tls_skip_verify = var.tls_skip_verify_vault_server
  ca_cert = var.vault_ca_cert != "" ? var.vault_ca_cert : null
}

resource "boundary_credential_library_vault" "this" {
  for_each = { for service in local.service_by_credential_path: element(split("/", service.credential_path), length(split("/", service.credential_path))-1) => service if service.type == "tcp" }

  path = each.value.credential_path
  credential_store_id = boundary_credential_store_vault.this.id

}


resource "boundary_credential_library_vault_ssh_certificate" "this" {
  for_each = { for service in local.service_by_credential_path: element(split("/", service.credential_path), length(split("/", service.credential_path))-1) => service if service.type == "ssh" }
  name = "SSH Key Signing"
  path = each.value.credential_path
  username = "ubuntu" #"{{.User.Name}}"
  key_type            = "ed25519"
  credential_store_id = boundary_credential_store_vault.this.id
  extensions = {
    permit-pty = ""
  }
}