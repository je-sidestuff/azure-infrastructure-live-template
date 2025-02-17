#!/bin/bash

# Script Name: populate_templates.sh
# Description: This script accepts a JSON payload as an argument, prints the
#              contents, creates an empty file, and returns a JSON payload
#              indicating success.  THIS IS A TEMPLATE SCRIPT AND SHOULD BE
#              REPLACED BY THE IMPLEMENTER WITH THEIR OWN CUSTOM LOGIC.

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

# Store the JSON payload in a variable
json_payload="$1"

# Extract the filename from the JSON payload.
filename=$(echo "$json_payload" | jq -r '.filename')

# Check if the filename was extracted successfully
if [ -z "$filename" ]; then
  print_error "Could not extract filename from JSON."
fi

# Create the file (touch creates an empty file)
touch "$filename"

# Print the success JSON payload
print_success
