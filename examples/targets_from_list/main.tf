data "hcp_packer_image" "this" {
  bucket_name    = "base-ubuntu-2204"
  channel        = "latest"
  cloud_provider = "vsphere"
  region         = "Datacenter"
}

module "vms" {
  source  = "github.com/tfo-apj-demos/terraform-vsphere-virtual-machine"

  count = 3

  hostname          = "vm-${count.index + 1}"
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

  hosts = [ for hostname, address in zipmap(module.vms.*.virtual_machine_name, module.vms.*.ip_address): { "hostname" = hostname, "address" = address } ]
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