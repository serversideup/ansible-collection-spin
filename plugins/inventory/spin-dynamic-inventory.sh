#!/bin/sh
ANSIBLE_WORK_DIR="${ANSIBLE_WORK_DIR:-$(pwd)}"
ANSIBLE_VARIABLE_FILE_NAME="${ANSIBLE_VARIABLE_FILE_NAME:-".spin.example.yml"}"
ANSIBLE_VARIABLE_FILEPATH="${ANSIBLE_VARIABLE_FILEPATH:-"${ANSIBLE_WORK_DIR}/${ANSIBLE_VARIABLE_FILE_NAME}"}"

generate_inventory() {
    yq eval -o=json "$ANSIBLE_VARIABLE_FILEPATH" | jq '
# Helper functions
def remove_null_hosts:
    walk(if type == "object" and has("hosts") and (.hosts | all(. == null)) then del(.hosts) else . end);

def add_server_to_groups($server):
    if $server.address and $server.environment == "production" and $server.environment != "production-worker" then
        {"servers_production_managers": {hosts: [$server.address]}}
    elif $server.address and $server.environment == "production-worker" then
        {"servers_production_workers": {hosts: [$server.address]}}
    elif $server.address and $server.environment == "staging" and $server.environment != "staging-worker" then
        {"servers_staging_managers": {hosts: [$server.address]}}
    elif $server.address and $server.environment == "staging-worker" then
        {"servers_staging_workers": {hosts: [$server.address]}}
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
    all: {children: ["ungrouped", "production", "staging"], hosts: []},
    ungrouped: {hosts: []},
    servers_production_managers: {hosts: []},
    servers_production_workers: {hosts: []},
    servers_staging_managers: {hosts: []},
    servers_staging_workers: {hosts: []},
    swarm_managers: {children: ["servers_production_managers", "servers_staging_managers"]},
    swarm_workers: {children: ["servers_production_workers", "servers_staging_workers"]},
    production: {children: ["servers_production_managers", "servers_production_workers"]},
    staging: {children: ["servers_staging_managers", "servers_staging_workers"]}
} as $base |

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

# Process environments
((.environments // []) | reduce .[] as $env (
    {};
    . * {("environment_" + $env.name): {hosts: [], vars: ($env | del(.name))}}
)) as $environment_result |

# Process servers
((.servers // []) | reduce .[] as $server (
    {};
    if $server.address then
        . * {
            ("environment_" + ($server.environment // "")): {
                hosts: [$server.address]
            },
            ("hardware_profile_" + ($server.hardware_profile // "")): {
                hosts: [$server.address]
            },
            ("server_" + $server.server_name): {
                hosts: [$server.address]
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
($base * $provider_result * $hardware_profile_result * $environment_result * $server_result) |
remove_null_hosts |
.all.hosts = ((.servers // []) | map(select(.address)) | map(.address)) |
.ungrouped.hosts = (.all.hosts - (
    [
        (.servers_production_managers.hosts // [])[], 
        (.servers_production_workers.hosts // [])[], 
        (.servers_staging_managers.hosts // [])[], 
        (.servers_staging_workers.hosts // [])[]
    ] | unique
)) |
# Ensure all groups exist, even if empty
.servers_production_managers.hosts //= [] |
.servers_production_workers.hosts //= [] |
.servers_staging_managers.hosts //= [] |
.servers_staging_workers.hosts //= [] |
# Add _meta.hostvars if not present
._meta.hostvars //= {}
'
}

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
