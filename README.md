# Boundary Target Terraform Module

This Terraform module is designed to create Boundary targets, credential stores, and credential libraries using HashiCorp Vault. It supports both SSH and TCP-based targets and allows flexible configurations with either Vault-generated or pre-existing credentials. This setup is ideal for securely accessing various services through Boundary, using a minimal set of inputs to simplify configuration.

## Features
- **Supports SSH and TCP Boundary targets**.
- **Credential management via Vault**: Automatically generates or references existing credentials.
- **Alias creation**: Optionally creates aliases for easy access.
- **Flexible configuration**: Configure single or grouped targets, with or without credentials.
- **Minimal input structure**: Simplifies configuration while allowing customization.

## Requirements
- **Terraform** >= 0.12
- **Boundary provider**
- **Vault provider**
- **Access to Vault and Boundary instances**

## Usage

### Example 1: TCP Target Without Credentials

```hcl
module "tcp_target_without_creds" {
  source        = "github.com/tfo-apj-demos/terraform-boundary-target"
  project_name  = "example_project"
  target_name   = "Example TCP Target"
  hosts         = ["example-tcp.target.local"]
  port          = 443
  target_type   = "tcp"

  # No Vault credentials required
  use_credentials = false

  # Alias name for easy access
  alias_name = "example-tcp.target.local"
}
```

### Example 2: TCP Target With Vault-Generated LDAP Credentials

```hcl
module "tcp_target_with_vault_creds" {
  source                 = "github.com/tfo-apj-demos/terraform-boundary-target"
  project_name           = "example_project"
  target_name            = "Example Vault TCP Target"
  hosts                  = ["example-vault-tcp.target.local"]
  port                   = 443
  target_type            = "tcp"

  # Vault credential configurations
  use_credentials        = true
  credential_store_token = vault_token.example_token.client_token
  vault_address          = "https://vault.example.com:8200"
  credential_source      = "vault"
  credential_path        = "ldap/creds/example-access"

  # Optional alias for accessing the target
  alias_name = "example-vault-tcp.target.local"
}

```

### Example 3: SSH Target With Existing Credential Libraries and Group Mode

```hcl
module "ssh_target_with_existing_creds" {
  source                     = "github.com/tfo-apj-demos/terraform-boundary-target"
  project_name               = "example_project"
  target_name                = "Example SSH Cluster Access"
  hosts                      = ["host1.example-ssh-cluster.local", "host2.example-ssh-cluster.local"]
  port                       = 22
  target_type                = "ssh"
  
  # No new Vault credentials; using existing credential libraries
  use_credentials            = false
  target_mode                = "group"

  # References to existing Vault credential store and SSH libraries
  existing_credential_store_id = "existing_cred_store_id"
  existing_ssh_credential_libraries = {
    "host1.example-ssh-cluster.local" = "clvsclt_12345",
    "host2.example-ssh-cluster.local" = "clvsclt_67890"
  }
}
```

### Example 4: Windows Remote Desktop Target With Vault-Generated Credentials

```hcl
module "rds_target_with_vault_creds" {
  source                     = "github.com/tfo-apj-demos/terraform-boundary-target"
  project_name               = "example_project"
  target_name                = "Windows RDS Target"
  hosts                      = ["rds-target.example.local"]
  port                       = 3389
  target_type                = "tcp"

  # Vault credential configurations
  use_credentials            = true
  credential_store_token     = vault_token.example_token.client_token
  vault_address              = "https://vault.example.com:8200"
  credential_source          = "vault"
  credential_path            = "ldap/creds/example-rds-access"

  # Reference existing credential store from another module instance
  existing_credential_store_id = module.another_module.credential_store_id

  # Alias name for accessing the RDS target
  alias_name = "rds-target.example.local"
}
```