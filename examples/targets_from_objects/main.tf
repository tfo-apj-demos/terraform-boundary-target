data "hcp_packer_image" "this" {
  bucket_name    = "base-ubuntu-2204"
  channel        = "latest"
  cloud_provider = "vsphere"
  region         = "Datacenter"
}

module "vms" {
  source  = "github.com/tfo-apj-demos/terraform-vsphere-virtual-machine"

  for_each = toset(["vm-1", "vm-2", "vm-3"])

  hostname          = each.value
  datacenter        = "Datacenter"
  cluster           = "cluster"
  primary_datastore = "vsanDatastore"
  folder_path       = "demo-workloads"
  networks = {
    "seg-general" : "dhcp"
  }

  template = data.hcp_packer_image.this.cloud_image_id
}

module "boundary_target" {
  source  = "github.com/tfo-apj-demos/terraform-boundary-target"

  hosts = [ for vm in module.vms: { "hostname" = vm.virtual_machine_name, "address" = vm.ip_address } ]
  services = [
    { 
      name = "ssh",
      type = "tcp",
      port = "22"
    }
  ]
  project_name = "grantorchard"
  host_catalog_id = "hcst_7B2FWBRqb0"
  hostname_prefix = "vm"
  injected_credential_library_ids = ["clvsclt_gmitu8xc09"]
}