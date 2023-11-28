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
  for_each     = { for service in var.services: service.name => service }
  name         = "${each.value.name}_${var.hostname_prefix}"
  type         = each.value.type
  default_port = each.value.port
  scope_id     = data.boundary_scope.project.id
  
  host_source_ids = [
    boundary_host_set_static.this.id
  ]

  injected_application_credential_source_ids = each.value.type != "ssh" ? null : var.injected_credential_library_ids
  brokered_credential_source_ids             = each.value.type == "ssh" ? null : var.brokered_credential_library_ids
  
  ingress_worker_filter = "\"vmware\" in \"/tags/platform\""
}

