# Server Update Ansible Role

A simple but robust role to safely update Ubuntu servers, handling package updates and automatic reboots when required. This role includes connection checking and proper wait times to ensure system stability.

## Requirements

- Target system must be Ubuntu/Debian-based (uses `apt` package manager)
- SSH access with sudo privileges
- Ansible 2.9 or higher

## Role Features

- Updates package cache
- Performs full system upgrade
- Removes unnecessary packages (autoremove)
- Cleans package cache (autoclean)
- Automatically handles required reboots
- Includes connection checking before and after updates
- Configurable timeout values

## Role Behavior

1. Verifies SSH connection is available (5-minute timeout)
2. Updates and upgrades all system packages
3. Checks if a system reboot is required
4. Performs automatic reboot if necessary
5. Waits for system to come back online
6. Verifies SSH connection is re-established

## Configuration

The role uses these default timeout values:
```yaml
# Initial connection timeout (in seconds)
connection_timeout: 300

# Package manager lock timeout (in seconds)
lock_timeout: 600

# Reboot timeout (in seconds)
reboot_timeout: 600
```

## Example Playbook

Basic usage:
```yaml
- hosts: servers
  roles:
    - role: update_server
```

With custom timeouts:
```yaml
- hosts: servers
  roles:
    - role: update_server
      vars:
        connection_timeout: 600    # 10 minutes
        lock_timeout: 1200         # 20 minutes
        reboot_timeout: 900        # 15 minutes
```

## Important Notes

- The update process may take several minutes depending on:
  - Server performance
  - Network connection speed
  - Number of packages to update
  - Whether a reboot is required
- The role includes appropriate wait times and connection checks to prevent SSH disconnection issues
- If the server requires a reboot, the role will handle it automatically
- The role is idempotent and can be run multiple times safely

## Dependencies

This role has no external dependencies beyond core Ansible modules. 