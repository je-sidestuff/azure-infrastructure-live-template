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

>&2 cd /tmp/
>&2 sudo apt-get install unzip
>&2 curl "https://releases.hashicorp.com/terraform/1.9.1/terraform_1.9.1_linux_amd64.zip" -o "terraform_1.9.1_linux_amd64.zip"
>&2 unzip terraform_1.9.1_linux_amd64.zip
>&2 sudo mv terraform /usr/local/bin/terraform
>&2 rm terraform_1.9.1_linux_amd64.zip

>&2 curl -L https://github.com/gruntwork-io/terragrunt/releases/download/v0.75.10/terragrunt_linux_amd64 -o terragrunt
>&2 chmod +x terragrunt
>&2 sudo mv terragrunt /usr/local/bin/terragrunt
>&2 cd -

# Read the JSON payload to feed into the terragrunt scaffolder
REPO_INIT_PAYLOAD="$1"

export TF_VAR_subscription_id="${SUBSCRIPTION_ID}"
TERRAGRUNT_SELF_BOOTSTRAP_DIR="${SCRIPT_DIR}/../../bootstrap/"
export TERRAGRUNT_SELF_BOOTSTRAP_SCAFFOLD_DIR="${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/scaffold"
TERRAGRNT_DEPLOYMENT_DIR="${SCRIPT_DIR}/../../deployment/"
export TERRAGRUNT_DEPLOYMENT_SCAFFOLD_DIR="${TERRAGRNT_DEPLOYMENT_DIR}/terragrunt/scaffold"

export BACKEND_JSON="$(echo ${REPO_INIT_PAYLOAD} | jq -r .backend)"
export SELF_BOOTSTRAP_SCAFFOLD_JSON_B64="$(echo ${REPO_INIT_PAYLOAD} | jq -r .self_bootstrap_scaffold_json_b64)"
export DEPLOY_SCAFFOLD_JSON_B64="$(echo ${REPO_INIT_PAYLOAD} | jq -r .deploy_scaffold_json_b64)"

# TODO - parameterize
export TGO_REF="support_self_bootstrapped_state_scaffold_fully"

# Scaffold our scaffolder so it can scaffold the remaining deployment tree
>&2 mkdir -p $TERRAGRUNT_DEPLOYMENT_SCAFFOLD_DIR
>&2 cd $TERRAGRUNT_DEPLOYMENT_SCAFFOLD_DIR
>&2  terragrunt scaffold github.com/je-sidestuff/terraform-github-orchestration//modules/terragrunt/scaffolder/from-json?ref=$TGO_REF --var=InputJsonB64="$DEPLOYMENT_SCAFFOLD_JSON_B64" --terragrunt-non-interactive
>&2 terragrunt run-all apply --terragrunt-non-interactive
>&2 echo "deploy scaffolded"
>&2 tree .
>&2 cd -

# Scaffold our scaffolder so it can scaffold the remaining self-bootstrap tree
>&2 mkdir -p $TERRAGRUNT_SELF_BOOTSTRAP_SCAFFOLD_DIR
>&2 cd $TERRAGRUNT_SELF_BOOTSTRAP_SCAFFOLD_DIR
>&2 terragrunt scaffold github.com/je-sidestuff/terraform-github-orchestration//modules/terragrunt/scaffolder/from-json?ref=$TGO_REF --var=InputJsonB64="$SELF_BOOTSTRAP_SCAFFOLD_JSON_B64" --terragrunt-non-interactive
>&2 terragrunt run-all apply --terragrunt-non-interactive
>&2 echo "bootstrap scaffolded"
>&2 tree .
>&2 cd -

# Temporarily use our holdover methods for generators and backends.
>&2 ${SCRIPT_DIR}/v0_holdovers.sh

>&2 cd $TERRAGRNT_SELF_BOOTSTRAP_DIR
>&2 terragrunt run-all plan --terragrunt-non-interactive -lock=false
if [ $? -eq 0 ]; then
    export TERRAGGRUNT_SUCCESS="true"
fi
>&2 cd -

if [ "${TERRAGGRUNT_SUCCESS}" == "true" ]; then
    print_success
fi
