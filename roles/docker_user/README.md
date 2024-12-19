# Docker User Ansible Role

Create and configure a dedicated user for Docker operations with proper permissions and SSH access. This role handles user creation, group management, and SSH key configuration.

## Requirements

This role is designed to work on Unix-like systems that support user and group management. It requires:
- Ansible 2.9 or higher
- Root or sudo access on the target system

## Role Variables

All configuration is handled through the `docker_user` dictionary in `defaults/main.yml`:

```yaml
docker_user:
  username: deploy            # Username for the Docker user
  uid: 9999                  # User ID
  group: deploy              # Primary group name
  secondary_groups: "docker" # Additional groups (comma-separated)
  gid: 9999                 # Group ID
  # Optional: Configure SSH keys directly in vars
  # authorized_ssh_keys: 
  #   - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKNJGtd7a4DBHsQi7HGrC5xz0eAEFHZ3Ogh3FEFI2345 fake@key"
```

The role also supports these additional variables:
- `deploy_public_key`: SSH public key added via "spin configure" command
- `users`: List of admin/sudo users whose SSH keys should be added to the Docker user

## Dependencies

Required Ansible collections (see `requirements.yml`):
```yaml
collections:
  - name: ansible.posix
```

To install dependencies:
```bash
ansible-galaxy install -r requirements.yml
```

## Features

- Creates a dedicated user for Docker operations
- Configures primary and secondary group memberships
- Manages SSH key access through multiple methods:
  - Direct configuration via `authorized_ssh_keys`
  - Integration with "spin configure" command
  - Automatic import of admin/sudo users' SSH keys
- Customizable user/group IDs and home directory
- Bash shell configuration

## Example Playbook

Basic usage:
```yaml
- hosts: servers
  roles:
    - role: docker_user
```

With custom configuration:
```yaml
- hosts: servers
  roles:
    - role: docker_user
      vars:
        docker_user:
          username: dockerops
          uid: 8888
          group: dockerops
          secondary_groups: "docker,www-data"
          gid: 8888
          authorized_ssh_keys:
            - "ssh-ed25519 AAAAC3... user@host"
```

## SSH Key Management

The role supports three methods for SSH key management, in order of precedence:

1. Keys specified in `docker_user.authorized_ssh_keys`
2. Key provided via `deploy_public_key` variable
3. SSH keys from users with sudo privileges

All valid keys will be added to the Docker user's `authorized_keys` file. 