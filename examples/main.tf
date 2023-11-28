module "boundary_targets" {
  source = "./.."

  project_name = "grantorchard"
  host_catalog_id = "hcst_7B2FWBRqb0"
  hostname_prefix = "foo"
  hosts = [
    {
      hostname = "gary"
      address = "192.168.0.2"
    },
    {
      hostname = "greg"
      address = "192.168.0.3"
    }
  ]
  services = [
    { 
      name = "postgres",
      type = "tcp",
      port = "5432"
    },
    { 
      name = "ssh",
      type = "tcp",
      port = "22"
    }
  ]
}