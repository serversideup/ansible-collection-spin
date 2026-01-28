#!/bin/bash
set -e

# Configuration - matches spin defaults
SPIN_ANSIBLE_IMAGE="${SPIN_ANSIBLE_IMAGE:-docker.io/serversideup/ansible-core:2.18-alpine}"
SPIN_USER_ID="${SPIN_USER_ID:-$(id -u)}"
SPIN_GROUP_ID="${SPIN_GROUP_ID:-$(id -g)}"
SPIN_RUN_AS_USER="${SPIN_RUN_AS_USER:-$(whoami)}"

show_help() {
  cat << EOF
Usage: ./dev.sh [OPTIONS] [-- ANSIBLE_ARGS]

Development script to build, install, and run the Spin Ansible collection.

By default, this script runs Ansible in Docker to match how "spin provision" works.
Use --local-ansible to run with your system's Ansible instead.

Options:
  -h, --help                 Show this help message
  --local-ansible            Use system Ansible instead of Docker (for debugging)
  --debug                    Enable debug output (ANSIBLE_STDOUT_CALLBACK=debug)
  --ask-vault-pass           Prompt for vault password (for encrypted .spin.yml)
  --vault-password-file FILE Use FILE as the vault password file

Environment Variables:
  ANSIBLE_WORK_DIR           Working directory (default: current directory)
  ANSIBLE_VARIABLE_FILE_NAME Variable file name (default: .spin.yml)
  ANSIBLE_VARIABLE_FILEPATH  Full path to variable file
  SPIN_ANSIBLE_IMAGE         Docker image to use (default: serversideup/ansible-core:2.18-alpine)

Examples:
  ./dev.sh                                        # Run with Docker (default)
  ./dev.sh --local-ansible                        # Run with system Ansible
  ./dev.sh --debug                                # Run with debug output
  ./dev.sh --vault-password-file .vault-password  # Use encrypted .spin.yml
  ./dev.sh --ask-vault-pass                       # Prompt for vault password
  ./dev.sh -- -vvv                                # Pass -vvv to ansible-playbook

EOF
}

# Initialize variables
use_docker=true
vault_args=()
docker_vault_args=()
extra_arguments=()
debug_mode=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    --local-ansible)
      use_docker=false
      shift
      ;;
    --debug)
      debug_mode=true
      shift
      ;;
    --ask-vault-pass)
      vault_args+=("--ask-vault-pass")
      docker_vault_args+=("--ask-vault-pass")
      shift
      ;;
    --vault-password-file)
      vault_args+=("--vault-password-file" "$2")
      # For Docker, we'll handle this separately since the path needs to be inside the container
      docker_vault_args+=("--vault-password-file" "/ansible/$(basename "$2")")
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
ANSIBLE_WORK_DIR="${ANSIBLE_WORK_DIR:-$(pwd)}"
ANSIBLE_VARIABLE_FILE_NAME="${ANSIBLE_VARIABLE_FILE_NAME:-".spin.yml"}"
ANSIBLE_VARIABLE_FILEPATH="${ANSIBLE_VARIABLE_FILEPATH:-"${ANSIBLE_WORK_DIR}/${ANSIBLE_VARIABLE_FILE_NAME}"}"

# Get the directory where this script lives (the collection source)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the collection
set -x
version=$(awk '/version:/ {print $2; exit}' "${SCRIPT_DIR}/galaxy.yml")
ansible-galaxy collection build "${SCRIPT_DIR}" --output-path "${SCRIPT_DIR}" --force

if [[ "$use_docker" == true ]]; then
  # Create a temporary directory for the collection installation
  COLLECTIONS_PATH=$(mktemp -d)
  trap "rm -rf $COLLECTIONS_PATH" EXIT

  # Install the collection AND its dependencies to the temporary directory
  # --force-with-deps ensures dependencies are installed even if they exist elsewhere
  ansible-galaxy collection install "${SCRIPT_DIR}/serversideup-spin-${version}.tar.gz" \
    -p "$COLLECTIONS_PATH" --force --force-with-deps

  # Build Docker arguments
  docker_args=(
    "--rm" "-it"
    "-e" "PUID=${SPIN_USER_ID}"
    "-e" "PGID=${SPIN_GROUP_ID}"
    "-e" "RUN_AS_USER=${SPIN_RUN_AS_USER}"
    "-e" "ANSIBLE_FORCE_COLOR=1"
    "-v" "${COLLECTIONS_PATH}:/etc/ansible/collections"
    "-v" "${ANSIBLE_WORK_DIR}:/ansible"
    "-w" "/ansible"
  )

  # Add debug environment variable if requested
  if [[ "$debug_mode" == true ]]; then
    docker_args+=("-e" "ANSIBLE_STDOUT_CALLBACK=debug")
  fi

  # Mount SSH directory if it exists
  if [[ -d "$HOME/.ssh" ]]; then
    docker_args+=("-v" "$HOME/.ssh/:/ssh/:ro")
    # Create known_hosts if it doesn't exist
    if [[ ! -f "$HOME/.ssh/known_hosts" ]]; then
      touch "$HOME/.ssh/known_hosts"
    fi
    docker_args+=("-v" "$HOME/.ssh/known_hosts:/ssh/known_hosts:rw")
  fi

  # Mount SSH Agent based on OS
  if [[ -n "$SSH_AUTH_SOCK" ]]; then
    case "$(uname -s)" in
      Darwin)
        # macOS
        docker_args+=(
          "-v" "/run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock"
          "-e" "SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock"
        )
        ;;
      Linux)
        # Linux (including WSL2)
        docker_args+=(
          "-v" "$SSH_AUTH_SOCK:$SSH_AUTH_SOCK"
          "-e" "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
        )
        ;;
    esac
  fi

  # Run Ansible in Docker
  docker run "${docker_args[@]}" \
    "$SPIN_ANSIBLE_IMAGE" \
    ansible-playbook \
      serversideup.spin.provision \
      --inventory /etc/ansible/collections/ansible_collections/serversideup/spin/plugins/inventory/spin-dynamic-inventory.sh \
      "${docker_vault_args[@]}" \
      --extra-vars "@./${ANSIBLE_VARIABLE_FILE_NAME}" \
      "${extra_arguments[@]}"
else
  # Local Ansible mode - original behavior
  ansible-galaxy collection install "${SCRIPT_DIR}/serversideup-spin-${version}.tar.gz" --force

  # Set debug mode for local Ansible
  if [[ "$debug_mode" == true ]]; then
    export ANSIBLE_STDOUT_CALLBACK=debug
  fi

  # Run the playbook locally
  ansible-playbook \
    -i "${SCRIPT_DIR}/plugins/inventory/spin-dynamic-inventory.sh" \
    "${SCRIPT_DIR}/playbooks/provision.yml" \
    "${vault_args[@]}" \
    --extra-vars "@${ANSIBLE_VARIABLE_FILEPATH}" \
    "${extra_arguments[@]}"
fi
