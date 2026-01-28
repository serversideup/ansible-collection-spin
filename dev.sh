#!/bin/bash
set -e
show_help() {
  cat << EOF
Usage: ./dev.sh [OPTIONS] [-- ANSIBLE_ARGS]

Development script to build, install, and run the Spin Ansible collection.

Options:
  -h, --help                 Show this help message
  --debug                    Enable debug output (ANSIBLE_STDOUT_CALLBACK=debug)
  --ask-vault-pass           Prompt for vault password (for encrypted .spin.yml)
  --vault-password-file FILE Use FILE as the vault password file

Environment Variables:
  ANSIBLE_WORK_DIR           Working directory (default: current directory)
  ANSIBLE_VARIABLE_FILE_NAME Variable file name (default: .spin.yml)
  ANSIBLE_VARIABLE_FILEPATH  Full path to variable file

Examples:
  ./dev.sh                                        # Run with defaults
  ./dev.sh --debug                                # Run with debug output
  ./dev.sh --vault-password-file .vault-password  # Use encrypted .spin.yml
  ./dev.sh --ask-vault-pass                       # Prompt for vault password
  ./dev.sh -- -vvv                                # Pass -vvv to ansible-playbook

EOF
}

# Initialize variables
vault_args=()
extra_arguments=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    --debug)
      export ANSIBLE_STDOUT_CALLBACK=debug
      shift
      ;;
    --ask-vault-pass)
      vault_args+=("--ask-vault-pass")
      shift
      ;;
    --vault-password-file)
      vault_args+=("--vault-password-file" "$2")
      shift 2
      ;;
    --)
      shift
      extra_arguments+=("$@")
      break
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

variable_file_path="${ANSIBLE_VARIABLE_FILEPATH}"

# Build and install the collection
set -x
version=$(awk '/version:/ {print $2; exit}' galaxy.yml)
ansible-galaxy collection build --force
ansible-galaxy collection install "serversideup-spin-${version}.tar.gz" --force

# Run the playbook
ansible-playbook \
  -i plugins/inventory/spin-dynamic-inventory.sh \
  playbooks/provision.yml \
  "${vault_args[@]}" \
  --extra-vars "@${variable_file_path}" \
  "${extra_arguments[@]}"
