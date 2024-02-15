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
  for_each = toset([
    for service in var.services: {
      for credential_path in service.credential_paths: element(split("/", credential_path), length(split("/", credential_path))-1) => service...
    }
  ])
  name         = "${each.key}_${var.hostname_prefix}"
  type         = each.value.type
  default_port = each.value.port
  scope_id     = data.boundary_scope.project.id
  
  host_source_ids = [
    boundary_host_set_static.this.id
  ]

  injected_application_credential_source_ids =  each.value.type == "tcp" ? boundary_credential_library_vault.this[each.key].id : null
  # injected_application_credential_source_ids = each.value.type != "ssh" ? null : var.injected_credential_library_ids
  # brokered_credential_source_ids             = each.value.type == "ssh" ? null : var.brokered_credential_library_ids
  
  ingress_worker_filter = "\"vmware\" in \"/tags/platform\""
}

resource "boundary_credential_store_vault" "this" {
  name = var.boundary_credential_store_vault_name
  token = var.credential_store_token
  scope_id = data.boundary_scope.project.id
  address = var.vault_address
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
  worker_filter = "\"vmware\" in \"/tags/platform\""
}

resource "boundary_credential_library_vault" "this" {
  #for_each = { for service in var.services: service.name => service if service.type == "tcp" }
  for_each = toset([
    for service in var.services: {
      for credential_path in service.credential_paths: element(split("/", credential_path), length(split("/", credential_path))-1) => service...
    }
  ])

  path = each.value.credential_path
  credential_store_id = boundary_credential_store_vault.this
}


resource "boundary_credential_library_vault_ssh_certificate" "this" {
  for_each = { for service in var.services: service.name => service if service.type == "ssh" }
  name = "SSH Key Signing"
  path = "ssh/sign/boundary"
  username = "ubuntu" #"{{.User.Name}}"
  key_type            = "ed25519"
  credential_store_id = boundary_credential_store_vault.this.id
  extensions = {
    permit-pty = ""
  }
}


#split("/", "postgres/creds/ws-x6gGqCdYqx2z97FH-read")[-1]
#element(split("/", credential_path), length(split("/", credential_path))-1)
# [ for service in { name = "postgres", type = "tcp", port = "5432", credential_paths = ["postgres/creds/ws-x6gGqCdYqx2z97FH-read"] } : { for credential_path in service.credential_paths: credential_path => service if service.type == "tcp"  } ]
# { name = "postgres", type = "tcp", port = "5432", credential_paths = ["postgres/creds/ws-x6gGqCdYqx2z97FH-read"] }