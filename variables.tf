variable "injected_credential_library_ids" {
  type = list(string)
  description = "Existing credential libraries that you want to assign to the target. Should only be used with SSH connections."
  default = [] #"clvsclt_gmitu8xc09"
}

variable "brokered_credential_library_ids" {
  type = list(string)
  description = "Existing credential libraries that you want to assign to the target. Should only be used with TCP connections."
  default = []
}

variable "host_catalog_id" {
  type = string
  description = "The existing id of the host catalog to register the hosts to."
}

variable "hostname_prefix" {
  type = string
  description = "A prefix to use for the Boundary host set."
}

variable "services" {
  type = list(object({
    name = string
    type = string
    port = number
  }))
  description = "A list of services to create targets for. Each combination of hosts and service will result in a unique target."
}

variable "hosts" {
  type = list(object({
    hostname = string
    address = string
  }))
  description = "The hosts to register as Boundary targets."
}

variable "project_name" {
  type = string
  description = "The Boundary project name in which to create the targets and associated resources."
}
