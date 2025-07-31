#!/bin/bash

# This file keeps the v0 techniques in place for backend and provider generation while that is not yet available properly.

>&2 echo "cat << EOT > ${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/backend-generator.hcl"

  # Create the backend-generator.hcl file
  cat << EOT > "${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/backend-generator.hcl"
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "${BACKEND_RESOURCE_GROUP}"
    storage_account_name = "${BACKEND_STORAGE_ACCOUNT}"
    container_name       = "${BACKEND_CONTAINER}"
    key                  = "\${path_relative_to_include()}/terraform.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
    }
}
EOF
}
EOT
  

>&2 echo "2cat << EOT > ${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/root.hcl"

  # Rewrite root.hcl as a workaround
  cat << EOT > "${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/root.hcl"
locals {
  # Automatically load subscription-level variables
  subscription_vars = read_terragrunt_config(find_in_parent_folders("subscription.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract the variables we need for easy access
  subscription_id = local.subscription_vars.locals.subscription_id
  # username     = local.account_vars.locals.username
  # account_name = local.account_vars.locals.account_name
  # aws_region   = local.region_vars.locals.aws_region
}

# Generate an Azure provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "azurerm" {
  subscription_id                 = "${SUBSCRIPTION_ID}"
  resource_provider_registrations = "all"
  use_msi                         = true
  use_oidc                        = true
  client_id                       = "${CLIENT_ID}"
  tenant_id                       = "${TENANT_ID}"
  features {}
}
EOF
}
EOT

  >&2 pwd
>&2 echo "3cat << EOT > ${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/root.hcl"
  >&2 cat "${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/backend-generator.hcl"

  # Extract the backend.resource_group, backend.storage_account and backend.container
  BACKEND_RESOURCE_GROUP="$(echo ${REPO_INIT_PAYLOAD} | jq -r .backend.resource_group)"
  BACKEND_STORAGE_ACCOUNT="$(echo ${REPO_INIT_PAYLOAD} | jq -r .backend.storage_account)"
  BACKEND_CONTAINER="$(echo ${REPO_INIT_PAYLOAD} | jq -r .backend.container)"

  # Create the backend-generator.hcl file
  cat << EOT > "${TERRAGRNT_DEPLOYMENT_DIR}/terragrunt/backend-generator.hcl"
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "${BACKEND_RESOURCE_GROUP}"
    storage_account_name = "${BACKEND_STORAGE_ACCOUNT}"
    container_name       = "${BACKEND_CONTAINER}"
    key                  = "\${path_relative_to_include()}/terraform.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
    }
}
EOF
}
EOT


  SUBSCRIPTION_ID="$(echo ${REPO_INIT_PAYLOAD} | jq -r .self_bootstrap.subscription_id)"
  
>&2 echo "4cat << EOT > ${TERRAGRNT_DEPLOYMENT_DIR}/terragrunt/root.hcl"

  # Rewrite root.hcl as a workaround
  cat << EOT > "${TERRAGRNT_DEPLOYMENT_DIR}/terragrunt/root.hcl"
locals {
  # Automatically load subscription-level variables
  subscription_vars = read_terragrunt_config(find_in_parent_folders("subscription.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract the variables we need for easy access
  subscription_id = local.subscription_vars.locals.subscription_id
  # username     = local.account_vars.locals.username
  # account_name = local.account_vars.locals.account_name
  # aws_region   = local.region_vars.locals.aws_region
}

# Generate an Azure provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "azurerm" {
  subscription_id                 = "${SUBSCRIPTION_ID}"
  resource_provider_registrations = "all"
  use_msi                         = true
  use_oidc                        = true
  client_id                       = "${CLIENT_ID}"
  tenant_id                       = "${TENANT_ID}"
  features {}
}
EOF
}
EOT