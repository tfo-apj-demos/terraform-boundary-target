variable "injected_credential_library_ids" {
  type        = list(string)
  description = "Existing credential libraries that you want to assign to the target. Should only be used with SSH connections."
  default     = [] #"clvsclt_gmitu8xc09"
}

variable "brokered_credential_library_ids" {
  type        = list(string)
  description = "Existing credential libraries that you want to assign to the target. Should only be used with TCP connections."
  default     = []
}

variable "hostname_prefix" {
  type        = string
  description = "A prefix to use for the Boundary host set."
}

variable "services" {
  type = list(object({
    name = string
    type = string
    port = number
    credential_paths = optional(list(string))
  }))
  description = "A list of services to create targets for. Each combination of hosts and service will result in a unique target."
}

variable "hosts" {
  type = list(object({
    hostname = string
    address  = string
  }))
  description = "The hosts to register as Boundary targets."
}

variable "project_name" {
  type        = string
  description = "The Boundary project name in which to create the targets and associated resources."
}

variable "vault_address" {
  type = string
  default = ""
}

variable "vault_namespace" {
  type = string
  default = ""
}

variable "ldap_credential_library" {
  description = "Determines if the LDAP credential library should be created"
  type        = bool
  default     = false
}

variable "credential_store_token" {
  type = string
  default = ""
}

variable "boundary_credential_store_vault_name" {
  type = string
  default = ""
}

variable "tls_skip_verify_vault_server" {
  type = bool
  default = false
}

variable "vault_ca_cert" {
  type = string
  default = ""
}