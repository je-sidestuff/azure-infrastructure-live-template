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

# Read the version if it is present. Default to v0 if no version is present.
INFRA_LIVE_VERSION="$(echo ${REPO_INIT_PAYLOAD} | jq -r .infra_live_version)"

# If we have no version default to v0
if [ -z "$INFRA_LIVE_VERSION" ]; then
  export INFRA_LIVE_VERSION="v0"
fi

# Verify that the version of the populate templates file is present
if [ ! -f "${SCRIPT_DIR}/${INFRA_LIVE_VERSION}_populate_templates.sh" ]; then
  print_error "No template file found for ${INFRA_LIVE_VERSION}. (File not found ${SCRIPT_DIR}/${INFRA_LIVE_VERSION}_populate_templates.sh)"
fi

"${SCRIPT_DIR}/${INFRA_LIVE_VERSION}_populate_templates.sh" "$@"
