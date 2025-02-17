#!/bin/bash

# Script to initialize a new git repository upon 'init' tag, 
# load a JSON payload, and begin template population.

# Function to handle errors and exit gracefully.
handle_error() {
  echo "Error: $1" >&2  # Print error message to stderr
  .smart-init/scripts/on_complete.sh "{\"status\": \"error\", \"message\": \"$1\"}"
  exit 1
}

# 1. Create git identity
git config --global user.email "initializer@smart-template.com"
git config --global user.name "initializer"

# 2. Detect Git Repository
git_url="$(git ls-remote --get-url origin)"
git_repo_dot_git="${git_url##*/}"
git_repo="${git_repo_dot_git%.git}"

echo "Running from git repository: $git_repo"

# If the repo name ends with 'template' print a message and exit
if [[ "$git_repo" == *template* ]]; then
    echo "This is a template repository, exiting."
    exit 0
fi

# 3. Load JSON Payload using jq
init_payload=$(jq . init_payload.json) # Loads the entire JSON object into the variable
if [[ $? -ne 0 ]]; then
    handle_error "Failed to load or parse init_payload.json. Aborting."
fi

echo "Loaded JSON payload: $init_payload"

INIT_RESULT=$(.smart-init/scripts/populate_templates.sh "$init_payload")

# Extract the 'status' and 'message' fields from the JSON result
status=$(echo "$INIT_RESULT" | jq -r '.status')
message=$(echo "$INIT_RESULT" | jq -r '.message')

echo "Template population complete. Result: $status - $message"

if [[ "$status" != "success" ]]; then
    handle_error "Template population failed. Aborting."
fi

.smart-init/scripts/on_complete.sh "$INIT_RESULT"
