output "host_catalog_id" {
  value = boundary_host_catalog_static.this.id
}

output "host_ids" {
  value = [for v in boundary_host_static.this : v.id]
}
