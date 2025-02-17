#!/bin/bash

# Commit all local changes with a message of $1, and push it to the remote repository.
# Then, create a tag with the name $2 and push that to the remote repository.
push_content_and_tag_to_git() {

    # Remove the initialization workflow - we do not want it to run again
    rm -rf .github/workflows/init.yaml

    git add --all
    git commit -m "$1"
    git push origin

    # Create and push the tag
    git tag "$2"
    git push origin "$2"
}

format_unexpected_failure() {
    echo "Error: $1"
    unexpected_failure_json="{\"status\": \"error\", \"message\": \"Unexpected failure during processing: $1\"}"
    echo "$unexpected_failure_json" > "init_failure_result.json"
    push_content_and_tag_to_git "Unexpected failure during processing: $1" "failed"
    exit 1
}


# Check if a JSON payload is provided as an argument
if [ -z "$1" ]; then
  echo "Error: JSON payload argument is missing."
  exit 1
fi

json_payload="$1"

# Extract status and message using jq
status=$(echo "$json_payload" | jq -r '.status')
message=$(echo "$json_payload" | jq -r '.message')

# Determine filename and tag based on status
if [[ "$status" == "success" ]]; then
  filename="init_success_result.json"
  tag="v0.0.0"
  commit_message="Initialization successful: $message"
elif [[ "$status" == "error" ]]; then
  filename="init_failure_result.json"
  tag="failed"
  commit_message="Initialization failed: $message"
else
  format_unexpected_failure "Invalid status: $status.  Must be 'success' or 'error'."
fi

# Write the JSON payload to the appropriate file
echo "$json_payload" > "$filename"

push_content_and_tag_to_git "$commit_message" "$tag"

echo "Initialization process completed."
