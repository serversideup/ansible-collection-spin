#!/bin/bash
set -x

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --debug)
      export ANSIBLE_STDOUT_CALLBACK=debug
      shift
      ;;
    *)
      extra_arguments+=("$1")
      shift
      ;;
  esac
done

# Set environment variables
export ANSIBLE_WORK_DIR="${ANSIBLE_WORK_DIR:-$(pwd)}"
export ANSIBLE_VARIABLE_FILE_NAME="${ANSIBLE_VARIABLE_FILE_NAME:-".spin.yml"}"
export ANSIBLE_VARIABLE_FILEPATH="${ANSIBLE_VARIABLE_FILEPATH:-"${ANSIBLE_WORK_DIR}/${ANSIBLE_VARIABLE_FILE_NAME}"}"

# Use ANSIBLE_VARIABLE_FILEPATH instead of variable_file_path
variable_file_path="${ANSIBLE_VARIABLE_FILEPATH}"

version=$(awk '/version:/ {print $2; exit}' galaxy.yml)
ansible-galaxy collection build --force
ansible-galaxy collection install "serversideup-spin-${version}.tar.gz" --force
ansible-playbook -i spin-dynamic-inventory.sh playbooks/provision.yml --extra-vars "@${variable_file_path}" "${extra_arguments[@]}"
