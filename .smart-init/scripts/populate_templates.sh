#!/bin/bash

# Script Name: populate_templates.sh
# Description: This script accepts a JSON payload as an argument, prints the
#              contents, creates an empty file, and returns a JSON payload
#              indicating success.  THIS IS A TEMPLATE SCRIPT AND SHOULD BE
#              REPLACED BY THE IMPLEMENTER WITH THEIR OWN CUSTOM LOGIC.


# We expect the json to look similar to this:
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

AZ_AUTH_CLIENT_ID="$(echo ${REPO_INIT_PAYLOAD} | jq -r .mi_client_id)"
AZ_AUTH_TENANT_ID="$(echo ${REPO_INIT_PAYLOAD} | jq -r .mi_tenant_id)"

SELF_BOOTSTRAP_SCAFFOLDING="$(echo ${REPO_INIT_PAYLOAD} | jq .self_bootstrap)"
SELF_BOOTSTRAP_SCAFFOLDING="$(echo ${SELF_BOOTSTRAP_SCAFFOLDING} | jq ".scaffolding_root += \"${TERRAGRNT_SELF_BOOTSTRAP_DIR}\"")"

export TEMP_DIR="$(mktemp -d -t infra-live-XXXX)"

cat << EOF > "${TEMP_DIR}/main.tf"
module "scaffolding" {
  source = "github.com/je-sidestuff/terraform-github-orchestration//modules/terragrunt/scaffolder/from-json/?ref=environment_deployment_support"

  input_json = <<EOT
${SELF_BOOTSTRAP_SCAFFOLDING}
EOT
}
EOF

>&2 cat ${TEMP_DIR}/main.tf

>&2 echo "Which terraform?"
>&2 which terraform

sudo apt-get install unzip
curl "https://releases.hashicorp.com/terraform/1.9.1/terraform_1.9.1_linux_amd64.zip" -o "terraform_1.9.1_linux_amd64.zip"
unzip terraform_1.9.1_linux_amd64.zip
sudo mv terraform /usr/local/bin/terraform

>&2 echo "Which terraform?"
>&2 which terraform

echo "Which terragrunt?"
which terragrunt

curl -L https://github.com/gruntwork-io/terragrunt/releases/download/v0.75.10/terragrunt_linux_amd64 -o terragrunt
chmod +x terragrunt
sudo mv terragrunt /usr/local/bin/terragrunt

>&2 echo "Which terragrunt?"
>&2 which terragrunt

cd "${TEMP_DIR}"
>&2 terraform init
>&2 terraform apply --auto-approve
cd -

>&2 echo "az login --identity --username ${AZ_AUTH_CLIENT_ID} --tenant ${AZ_AUTH_TENANT_ID}"
>&2 az login --identity --username ${AZ_AUTH_CLIENT_ID} --tenant ${AZ_AUTH_TENANT_ID}

cd "${TERRAGRNT_SELF_BOOTSTRAP_DIR}/terragrunt/sandbox" 
>&2 ls -latr
>&2 terragrunt run-all apply --terragrunt-non-interactive 
cd -

>&2 tree -d ${TEMP_DIR}
>&2 tree -d ${TERRAGRNT_SELF_BOOTSTRAP_DIR}

# # Extract the filename from the JSON payload.
# filename=$(echo "$json_payload" | jq -r '.filename')

# # Check if the filename was extracted successfully
# if [ -z "$filename" ]; then
#   print_error "Could not extract filename from JSON."
# fi

# # Create the file (touch creates an empty file)
# touch "$filename"

# # Print the success JSON payload
# print_success
