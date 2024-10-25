#!/bin/sh
ANSIBLE_WORK_DIR="${ANSIBLE_WORK_DIR:-$(pwd)}"
ANSIBLE_VARIABLE_FILE_NAME="${ANSIBLE_VARIABLE_FILE_NAME:-".spin.yml"}"
ANSIBLE_VARIABLE_FILEPATH="${ANSIBLE_VARIABLE_FILEPATH:-"${ANSIBLE_WORK_DIR}/${ANSIBLE_VARIABLE_FILE_NAME}"}"

##############################################################
# Functions
##############################################################

is_valid_ipv4() {
  echo "$1" | awk -F. '{
    if (NF != 4) exit 1
    for (i=1; i<=4; i++) {
      if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1
    }
    exit 0
  }'
}

is_valid_ipv6() {
  echo "$1" | awk -F: '{
    if (NF < 3 || NF > 8) exit 1
    for (i=1; i<=NF; i++) {
      if ($i !~ /^[0-9a-fA-F]{0,4}$/) exit 1
    }
    exit 0
  }'
}

get_backups_value() {
  server_name="$1"
  file="$ANSIBLE_VARIABLE_FILEPATH"

  # Get backups value from server, environment, hardware profile, and provider in order of precedence
  server_backups=$(yq eval ".servers[] | select(.server_name == \"$server_name\") | .backups" "$file")
  environment=$(yq eval ".servers[] | select(.server_name == \"$server_name\") | .environment" "$file")
  environment_backups=$(yq eval ".environments[] | select(.name == \"$environment\") | .backups" "$file")
  hardware_profile=$(yq eval ".servers[] | select(.server_name == \"$server_name\") | .hardware_profile" "$file")
  hardware_profile_backups=$(yq eval ".hardware_profiles[] | select(.name == \"$hardware_profile\") | .backups" "$file")
  provider=$(yq eval ".hardware_profiles[] | select(.name == \"$hardware_profile\") | .provider" "$file")
  provider_backups=$(yq eval ".providers[] | select(.name == \"$provider\") | .backups" "$file")

  # Determine the final backups value based on precedence
  if [ "$server_backups" != "null" ]; then
    echo "$server_backups"
  elif [ "$environment_backups" != "null" ]; then
    echo "$environment_backups"
  elif [ "$hardware_profile_backups" != "null" ]; then
    echo "$hardware_profile_backups"
  elif [ "$provider_backups" != "null" ]; then
    echo "$provider_backups"
  else
    echo "null"
  fi
}

validate_inventory() {
  file="$ANSIBLE_VARIABLE_FILEPATH"
  addresses=$(yq eval '.servers[] | select(.server_address != null) | .server_address' "$file")
  server_names=$(yq eval '.servers[] | select(.server_name != null) | .server_name' "$file")

  # Validate server addresses are valid DNS hostnames, IPv4, or IPv6 addresses
  invalid_addresses=$(echo "$addresses" | while read -r address; do
    if ! (is_valid_ipv4 "$address" || is_valid_ipv6 "$address" || echo "$address" | grep -Eq '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'); then
      echo "$address"
    fi
  done)

  if [ -n "$invalid_addresses" ]; then
    echo "[ERROR] Invalid inventory file. Invalid server addresses found:"
    echo "$invalid_addresses"
    exit 1
  fi

  # Check for unique server names
  duplicate_names=$(echo "$server_names" | sort | uniq -d)
  if [ -n "$duplicate_names" ]; then
    echo "[ERROR] Invalid inventory file. Duplicate server names found:"
    echo "$duplicate_names"
    exit 1
  fi

  # Check for unique server addresses
  duplicate_addresses=$(echo "$addresses" | sort | uniq -d)
  if [ -n "$duplicate_addresses" ]; then
    echo "[ERROR] Invalid inventory file. Duplicate server addresses found:"
    echo "$duplicate_addresses"
    exit 1
  fi
}

generate_inventory() {
  file="$ANSIBLE_VARIABLE_FILEPATH"

  validate_inventory

  # Basic Server configuration
  echo "[servers_production_managers]"
  yq eval '.servers[] | select(.environment == "production" and .server_address != null) | .server_address' "$file"

  echo "[servers_production_workers]"
  yq eval '.servers[] | select(.environment == "production-worker" and .server_address != null) | .server_address' "$file"

  echo "[servers_staging_managers]"
  yq eval '.servers[] | select(.environment == "staging" and .server_address != null) | .server_address' "$file"

  echo "[servers_staging_workers]"
  yq eval '.servers[] | select(.environment == "staging-worker" and .server_address != null) | .server_address' "$file"

  echo "[servers_development_managers]"
  yq eval '.servers[] | select(.environment == "development" and .server_address != null) | .server_address' "$file"

  echo "[servers_development_workers]"
  yq eval '.servers[] | select(.environment == "development-worker" and .server_address != null) | .server_address' "$file"

  # Swarm Configuration
  echo "[swarm_managers:children]"
  echo "servers_production_managers"
  echo "servers_staging_managers"
  echo "servers_development_managers"

  echo "[swarm_workers:children]"
  echo "servers_production_workers"
  echo "servers_staging_workers"
  echo "servers_development_workers"

  # Environments
  echo "[production:children]"
  echo "servers_production_managers"
  echo "servers_production_workers"

  echo "[staging:children]"
  echo "servers_staging_managers"
  echo "servers_staging_workers"

  echo "[development:children]"
  echo "servers_development_managers"
  echo "servers_development_workers"

  echo "[all_servers:children]"
  echo "production"
  echo "staging"
  echo "development"

  # Providers
  yq eval '.providers[] | .name' "$file" | while read -r provider; do
    echo "[provider_$provider]"
    yq eval ".servers[] | select(.hardware_profile | test(\"^.*-${provider}-.*$\")) | .server_address" "$file" | while read -r server_address; do
      echo "$server_address"
    done
    echo "[provider_$provider:vars]"
    yq eval ".providers[] | select(.name == \"$provider\") | to_entries | .[] | \"\\(.key)=\\(.value)\"" "$file" | while read -r line; do
      echo "$line"
    done
  done

  # Hardware Profiles
  yq eval '.hardware_profiles[] | .name' "$file" | while read -r profile; do
    echo "[hardware_profile_$profile]"
    servers=$(yq eval ".servers[] | select(.hardware_profile == \"$profile\" and .server_address != null) | .server_address" "$file")
    if [ -n "$servers" ]; then
      echo "$servers"
    fi
    profile_backups=$(yq eval ".hardware_profiles[] | select(.name == \"$profile\") | .backups" "$file")
    if [ "$profile_backups" = "true" ] || [ "$profile_backups" = "false" ]; then
      echo "[hardware_profile_$profile:vars]"
      echo "backups=$profile_backups"
    fi
  done

  # Environments
  yq eval '.environments[] | .name' "$file" | while read -r environment; do
    echo "[environment_$environment]"
    servers=$(yq eval ".servers[] | select(.environment == \"$environment\" and .server_address != null) | .server_address" "$file")
    if [ -n "$servers" ]; then
      echo "$servers"
    fi
    environment_backups=$(yq eval ".environments[] | select(.name == \"$environment\") | .backups" "$file")
    if [ "$environment_backups" = "true" ] || [ "$environment_backups" = "false" ]; then
      echo "[environment_$environment:vars]"
      echo "backups=$environment_backups"
    fi
  done

  # Servers
  yq eval -o=json '.servers[]' "$file" | jq -c '.' | while read -r server; do
    server_name=$(echo "$server" | jq -r '.server_name')
    server_address=$(echo "$server" | jq -r '.server_address // empty')

    echo "[server_$server_name]"
    if [ -n "$server_address" ]; then
      echo "$server_address"
    fi

    echo "[server_${server_name}:vars]"
    echo "$server" | jq -r 'to_entries[] | select(.value != null) | "\(.key)=\(.value)"'
  done
}

# Function to display colorized output
display_colorized() {
  generate_inventory | awk '
    /^\[.*\]$/ {print "\033[1;34m" $0 "\033[0m"; next}
    {print}'
}

##############################################################
# Main
##############################################################

if [ ! -f "$ANSIBLE_VARIABLE_FILEPATH" ]; then
  echo "Error: Variable file '$ANSIBLE_VARIABLE_FILEPATH' not found."
  exit 1
fi

# TODO: Add support for decrypting `.spin.yml` with Ansible Vault
# TODO: Add support for `.spin.inventory.yml`

# Check for colorized output flag
if [ "$1" = "--color" ]; then
  display_colorized
else
  generate_inventory
fi
