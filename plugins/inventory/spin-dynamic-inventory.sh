#!/bin/sh
ANSIBLE_WORK_DIR="${ANSIBLE_WORK_DIR:-$(pwd)}"
ANSIBLE_VARIABLE_FILE_NAME="${ANSIBLE_VARIABLE_FILE_NAME:-".spin.yml"}"
ANSIBLE_VARIABLE_FILEPATH="${ANSIBLE_VARIABLE_FILEPATH:-"${ANSIBLE_WORK_DIR}/${ANSIBLE_VARIABLE_FILE_NAME}"}"

##############################################################
# Functions
##############################################################

generate_inventory() {
    validate_inventory
    yq eval -o=json "$ANSIBLE_VARIABLE_FILEPATH" | jq '
# Helper functions
def remove_null_hosts:
    walk(if type == "object" and has("hosts") and (.hosts | all(. == null)) then del(.hosts) else . end);

def add_server_to_groups($server):
    if $server.address and $server.environment then
        if ($server.environment | endswith("_workers")) then
            {("servers_" + $server.environment): {hosts: ((.["servers_" + $server.environment].hosts // []) + [$server.address])}}
        else
            {("servers_" + $server.environment + "_managers"): {hosts: ((.["servers_" + $server.environment + "_managers"].hosts // []) + [$server.address])}}
        end
    else
        {}
    end;

def merge_vars($server):
    (.["provider_" + ($server.provider // "")].vars // {}) *
    (.["hardware_profile_" + ($server.hardware_profile // "")].vars // {}) *
    (.["environment_" + ($server.environment // "")].vars // {}) *
    $server;

# Base structure
{
    _meta: {hostvars: {}},
    all: {children: ["ungrouped"], hosts: []},
    ungrouped: {hosts: []}
} as $initial_base |

# Build dynamic base structure from environments
(.environments // [] | reduce .[] as $env (
    $initial_base;
    . * {
        ("servers_" + $env.name + "_managers"): {hosts: []},
        ("servers_" + $env.name + "_workers"): {hosts: []},
        ($env.name): {children: [
            ("servers_" + $env.name + "_managers"),
            ("servers_" + $env.name + "_workers")
        ]},
        "all": {
            children: (.all.children + [$env.name])
        },
        "swarm_managers": {
            children: ((.swarm_managers.children // []) + [("servers_" + $env.name + "_managers")])
        },
        "swarm_workers": {
            children: ((.swarm_workers.children // []) + [("servers_" + $env.name + "_workers")])
        }
    }
)) as $base |

# Process providers
((.providers // []) | reduce .[] as $provider (
    {};
    . * {("provider_" + $provider.name): {vars: ($provider | del(.name))}}
)) as $provider_result |

# Process hardware profiles
((.hardware_profiles // []) | reduce .[] as $profile (
    {};
    . * {
        ("hardware_profile_" + $profile.name): {
            hosts: [],
            vars: $profile.profile_config
        },
        ("provider_" + $profile.provider): {
            children: [("hardware_profile_" + $profile.name)]
        }
    }
)) as $hardware_profile_result |

# Process servers
((.servers // []) | reduce .[] as $server (
    {};
    if $server.address then
        . * {
            ("hardware_profile_" + ($server.hardware_profile // "")): {
                hosts: (
                    (.[("hardware_profile_" + ($server.hardware_profile // ""))].hosts // []) + 
                    [$server.address]
                )
            },
            _meta: {
                hostvars: {
                    ($server.address): merge_vars($server)
                }
            }
        } * 
        add_server_to_groups($server)
    else
        .
    end
)) as $server_result |

# Combine all results
($base * $provider_result * $hardware_profile_result * $server_result) |
remove_null_hosts |
.all.hosts = ((.servers // []) | map(select(.address)) | map(.address)) |
.ungrouped.hosts = (.all.hosts - (
    [
        (.environments // [] | .[].name | . as $env |
            [(["servers_" + $env + "_managers", "servers_" + $env + "_workers"] | 
            map(.[].hosts // [])[])]
        )[]
    ] | flatten | unique
)) |
# Add _meta.hostvars if not present
._meta.hostvars //= {}
'
}

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

validate_inventory() {
  file="$ANSIBLE_VARIABLE_FILEPATH"
  
  # Extract server addresses and names using the new path structure
  addresses=$(yq eval '.servers[] | select(.address != null) | .address' "$file")
  server_names=$(yq eval '.servers[] | select(.server_name != null) | .server_name' "$file")
  environments=$(yq eval '.servers[] | select(.environment != null) | .environment' "$file")
  hardware_profiles=$(yq eval '.servers[] | select(.hardware_profile != null) | .hardware_profile' "$file")
  
  # Validate server addresses
  invalid_addresses=$(echo "$addresses" | while read -r address; do
    if [ -n "$address" ] && ! (is_valid_ipv4 "$address" || is_valid_ipv6 "$address" || echo "$address" | grep -Eq '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'); then
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

  # Check for unique server addresses (only for non-empty addresses)
  duplicate_addresses=$(echo "$addresses" | grep -v '^$' | sort | uniq -d)
  if [ -n "$duplicate_addresses" ]; then
    echo "[ERROR] Invalid inventory file. Duplicate server addresses found:"
    echo "$duplicate_addresses"
    exit 1
  fi

  # Validate environments against defined environments
  defined_environments=$(yq eval '.environments[].name' "$file")
  # Create extended environment list with _workers and _managers variants
  extended_environments=$(echo "$defined_environments" | while read -r env; do
    echo "$env"
    echo "${env}_workers"
    echo "${env}_managers"
  done)
  
  invalid_environments=$(echo "$environments" | while read -r env; do
    if ! echo "$extended_environments" | grep -q "^${env}$"; then
      echo "$env"
    fi
  done)

  if [ -n "$invalid_environments" ]; then
    echo "[ERROR] Invalid inventory file. Undefined environments found:"
    echo "$invalid_environments"
    exit 1
  fi

  # Validate hardware profiles against defined profiles
  defined_profiles=$(yq eval '.hardware_profiles[].name' "$file")
  invalid_profiles=$(echo "$hardware_profiles" | while read -r profile; do
    if ! echo "$defined_profiles" | grep -q "^${profile}$"; then
      echo "$profile"
    fi
  done)

  if [ -n "$invalid_profiles" ]; then
    echo "[ERROR] Invalid inventory file. Undefined hardware profiles found:"
    echo "$invalid_profiles"
    exit 1
  fi

  # Validate names against Ansible standards
  validate_ansible_name() {
    local name="$1"
    local type="$2"
    if ! echo "$name" | grep -Eq '^[a-zA-Z_][a-zA-Z0-9_]*$'; then
      echo "$name ($type)"
    fi
  }

  # Check server names
  invalid_ansible_names=$(
    # Check environment names
    yq eval '.environments[].name' "$file" | while read -r name; do
      validate_ansible_name "$name" "environment"
    done

    # Check hardware profile names
    yq eval '.hardware_profiles[].name' "$file" | while read -r name; do
      validate_ansible_name "$name" "hardware_profile"
    done

    # Check provider names
    yq eval '.providers[].name' "$file" | while read -r name; do
      validate_ansible_name "$name" "provider"
    done
  )

  if [ -n "$invalid_ansible_names" ]; then
    echo "[ERROR] Invalid inventory file. Names not following Ansible standards (must start with letter/underscore, contain only letters/numbers/underscores):"
    echo "$invalid_ansible_names"
    exit 1
  fi
}

##############################################################
# Main
##############################################################

case "$1" in
    --list|"")
        generate_inventory
        ;;
    --host)
        if [ -z "$2" ]; then
            echo "Usage: $0 --host <hostname>" >&2
            exit 1
        fi
        generate_inventory | jq --arg hostname "$2" '._meta.hostvars[$hostname] // {}'
        ;;
    *)
        echo "Usage: $0 [--list|--host <hostname>]" >&2
        exit 1
        ;;
esac
