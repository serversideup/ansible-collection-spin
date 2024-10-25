#!/bin/bash
set -x

# Set environment variables
export ANSIBLE_WORK_DIR="${ANSIBLE_WORK_DIR:-$(pwd)}"
export ANSIBLE_VARIABLE_FILE_NAME="${ANSIBLE_VARIABLE_FILE_NAME:-".spin.yml"}"
export ANSIBLE_VARIABLE_FILEPATH="${ANSIBLE_VARIABLE_FILEPATH:-"${ANSIBLE_WORK_DIR}/${ANSIBLE_VARIABLE_FILE_NAME}"}"

# Use ANSIBLE_VARIABLE_FILEPATH instead of variable_file_path
variable_file_path="${ANSIBLE_VARIABLE_FILEPATH}"

version=$(awk '/version:/ {print $2; exit}' galaxy.yml)
ansible-galaxy collection build --force
ansible-galaxy collection install "serversideup-spin-${version}.tar.gz" --force
ansible-playbook -i spin-dynamic-inventory.sh playbooks/provision.yml --extra-vars "@${variable_file_path}"
