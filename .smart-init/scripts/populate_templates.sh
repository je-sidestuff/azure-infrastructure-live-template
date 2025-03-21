#!/bin/bash

# Script Name: populate_templates.sh
# Description: This script accepts a JSON payload as an argument, prints the
#              contents, creates an empty file, and returns a JSON payload
#              indicating success.  THIS IS A TEMPLATE SCRIPT AND SHOULD BE
#              REPLACED BY THE IMPLEMENTER WITH THEIR OWN CUSTOM LOGIC.


# We expect the json to look similar to this: (TODO: update this)
# {
#   "targets":{
#     "storage_account" : {
#       "repo": "je-sidestuff/terraform-azure-simple-modules",
#       "path": "modules/data-stores/storage-account/",
#       "desc": "",
#       "placement": {
#         "region": "eastus",
#         "env": "default",
#         "subscription": "main"
#       }
#     },
#     "other_storage_account" : {
#       "repo": "je-sidestuff/terraform-azure-simple-modules",
#       "path": "modules/data-stores/storage-account/",
#       "desc": "other",
#       "placement": {
#         "region": "eastus",
#         "env": "_global",
#         "subscription": "main"
#       }
#     }
#   }
# }

# Function to print a JSON error message and exit
print_error() {
  echo "{\"status\": \"error\", \"message\": \"$1\"}"
  exit 1
}

# Function to print a JSON success message
print_success() {
  echo "{\"status\": \"success\", \"message\": \"File created successfully.\"}"
}

# Check if a JSON payload argument is provided
if [ -z "$1" ]; then
  print_error "No JSON payload provided."
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Read the JSON payload to feed into the terragrunt scaffolder
REPO_INIT_PAYLOAD="$1"

TERRAGRNT_SELF_BOOTSTRAP_DIR="${SCRIPT_DIR}/../../bootstrap/"
TERRAGRNT_DEPLOYMENT_DIR="${SCRIPT_DIR}/../../deployment/"

AZ_AUTH_CLIENT_ID="$(echo ${REPO_INIT_PAYLOAD} | jq -r .mi_client_id)"

SELF_BOOTSTRAP_SCAFFOLDING="$(echo ${REPO_INIT_PAYLOAD} | jq .self_bootstrap)"
SELF_BOOTSTRAP_SCAFFOLDING="$(echo ${SELF_BOOTSTRAP_SCAFFOLDING} | jq ".scaffolding_root += \"${TERRAGRNT_SELF_BOOTSTRAP_DIR}\"")"
DEPLOYMENT_SCAFFOLDING="$(echo ${REPO_INIT_PAYLOAD} | jq .deployment)"
DEPLOYMENT_SCAFFOLDING="$(echo ${DEPLOYMENT_SCAFFOLDING} | jq ".scaffolding_root += \"${TERRAGRNT_DEPLOYMENT_DIR}\"")"

export TEMP_DIR="$(mktemp -d -t infra-live-XXXX)"

cat << EOF > "${TEMP_DIR}/main.tf"
module "bootstrap_scaffolding" {
  source = "github.com/je-sidestuff/terraform-github-orchestration//modules/terragrunt/scaffolder/from-json/?ref=environment_deployment_support"

  input_json = <<EOT
${SELF_BOOTSTRAP_SCAFFOLDING}
EOT
}

module "deployment_scaffolding" {
  source = "github.com/je-sidestuff/terraform-github-orchestration//modules/terragrunt/scaffolder/from-json/?ref=environment_deployment_support"

  input_json = <<EOT
${DEPLOYMENT_SCAFFOLDING}
EOT
}
EOF

>&2 cat ${TEMP_DIR}/main.tf

>&2 sudo apt-get install unzip
>&2 curl "https://releases.hashicorp.com/terraform/1.9.1/terraform_1.9.1_linux_amd64.zip" -o "terraform_1.9.1_linux_amd64.zip"
>&2 unzip terraform_1.9.1_linux_amd64.zip
>&2 sudo mv terraform /usr/local/bin/terraform

>&2 curl -L https://github.com/gruntwork-io/terragrunt/releases/download/v0.75.10/terragrunt_linux_amd64 -o terragrunt
>&2 chmod +x terragrunt
>&2 sudo mv terragrunt /usr/local/bin/terragrunt

>&2 cd "${TEMP_DIR}"
>&2 terraform init
>&2 terraform apply --auto-approve
>&2 cd -

# Check if the init payload contains the top level key 'backend'
if [ -n "$(echo ${REPO_INIT_PAYLOAD} | jq .backend)" ]; then
  # Extract the backend.resource_group, backend.storage_account and backend.container
  BACKEND_RESOURCE_GROUP="$(echo ${REPO_INIT_PAYLOAD} | jq -r .backend.resource_group)"
  BACKEND_STORAGE_ACCOUNT="$(echo ${REPO_INIT_PAYLOAD} | jq -r .backend.storage_account)"
  BACKEND_CONTAINER="$(echo ${REPO_INIT_PAYLOAD} | jq -r .backend.container)"

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


  SUBSCRIPTION_ID="$(echo ${REPO_INIT_PAYLOAD} | jq -r .self_bootstrap.subscription_id)"
  
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
  >&2 cat "${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/backend-generator.hcl"

fi

>&2 az storage account list

>&2 az storage account show --ids "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${BACKEND_RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${BACKEND_STORAGE_ACCOUNT}"

>&2 az storage container exists --account-name ${BACKEND_STORAGE_ACCOUNT} --name ${BACKEND_CONTAINER}

>&2 az storage blob list -c ${BACKEND_CONTAINER} --account-name ${BACKEND_STORAGE_ACCOUNT}

export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
export ARM_TENANT_ID=${TENANT_ID}
export ARM_CLIENT_ID=${CLIENT_ID}

>&2 cd "${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/sandbox" 
>&2 ls -latr
>&2 terragrunt run-all plan --terragrunt-non-interactive
if [ $? -eq 0 ]; then
    export TERRAGGRUNT_SUCCESS="true"
fi
>&2 cd -

>&2 tree -d "${TERRAGRNT_DEPLOYMENT_DIR}/.."
>&2 tree "${TERRAGRNT_DEPLOYMENT_DIR}/.."

if [ "${TERRAGGRUNT_SUCCESS}" == "true" ]; then
    print_success
fi
