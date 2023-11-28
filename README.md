<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_boundary"></a> [boundary](#requirement\_boundary) | ~> 1.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_boundary"></a> [boundary](#provider\_boundary) | ~> 1.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [boundary_host_set_static.this](https://registry.terraform.io/providers/hashicorp/boundary/latest/docs/resources/host_set_static) | resource |
| [boundary_host_static.this](https://registry.terraform.io/providers/hashicorp/boundary/latest/docs/resources/host_static) | resource |
| [boundary_target.this](https://registry.terraform.io/providers/hashicorp/boundary/latest/docs/resources/target) | resource |
| [boundary_scope.org](https://registry.terraform.io/providers/hashicorp/boundary/latest/docs/data-sources/scope) | data source |
| [boundary_scope.project](https://registry.terraform.io/providers/hashicorp/boundary/latest/docs/data-sources/scope) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_brokered_credential_library_ids"></a> [brokered\_credential\_library\_ids](#input\_brokered\_credential\_library\_ids) | Existing credential libraries that you want to assign to the target. Should only be used with TCP connections. | `list(string)` | n/a | yes |
| <a name="input_host_catalog_id"></a> [host\_catalog\_id](#input\_host\_catalog\_id) | The existing id of the host catalog to register the hosts to. | `string` | n/a | yes |
| <a name="input_hostname_prefix"></a> [hostname\_prefix](#input\_hostname\_prefix) | A prefix to use for the Boundary host set. | `string` | n/a | yes |
| <a name="input_hosts"></a> [hosts](#input\_hosts) | The hosts to register as targets. | <pre>list(object({<br>    hostname = string<br>    address = string<br>  }))</pre> | n/a | yes |
| <a name="input_injected_credential_library_ids"></a> [injected\_credential\_library\_ids](#input\_injected\_credential\_library\_ids) | Existing credential libraries that you want to assign to the target. Should only be used with SSH connections. | `list(string)` | `[]` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The Boundary project name in which to create the targets and associated resources. | `string` | n/a | yes |
| <a name="input_services"></a> [services](#input\_services) | A list of services to create targets for. Each combination of hosts and service will result in a unique target. | <pre>list(object({<br>    name = string<br>    type = string<br>    port = number<br>  }))</pre> | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->