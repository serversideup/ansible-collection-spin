# Docker Swarm Ansible Role

Deploy and maintain Docker Swarm servers easily. This role was inspired by [Jeff Geerling](https://github.com/geerlingguy), but expanded to support Docker Swarm. Please support his amazing work!

## Requirements

For now, this project focuses on supporting **Ubuntu 22.04** only. Choose any host that you'd like. All this role needs is an SSH connection to a user that has `sudo` privileges.

## Role Variables

You can find all variables organized and documented in `defaults/main.yml`. Feel free to override any variable of your choice.

```yml
---
# Edition can be one of: 'ce' (Community Edition) or 'ee' (Enterprise Edition).
docker_edition: 'ce'

# Docker repo URL.
docker_repo_url: https://download.docker.com/linux

# Used only for Debian/Ubuntu. Switch 'stable' to 'nightly' if needed.
docker_apt_release_channel: stable
docker_apt_arch: "{{ 'arm64' if ansible_architecture == 'aarch64' else 'amd64' }}"
docker_apt_repository: "deb [arch={{ docker_apt_arch }} signed-by=/etc/apt/trusted.gpg.d/docker.asc] {{ docker_repo_url }}/{{ ansible_distribution | lower }} {{ ansible_distribution_release }} {{ docker_apt_release_channel }}"
docker_apt_ignore_key_error: true
docker_apt_gpg_key: "{{ docker_repo_url }}/{{ ansible_distribution | lower }}/gpg"
docker_apt_gpg_key_checksum: "sha256:1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570"

# Docker user configuration.
docker_user:
  username: deploy
  uid: 9999
  group: deploy
  secondary_groups: "docker"
  gid: 9999
  ## Uncomment to set authorized SSH keys for the docker user.
  # authorized_ssh_keys: 
  #   - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKNJGtd7a4DBHsQi7HGrC5xz0eAEFHZ3Ogh3FEFI2345 fake@key"
  #   - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRfXxUZ8q9vHRcQZ6tLb0KwGHu8xjQHfYopZKLmnopQ anotherfake@key"
```

### Dependencies
See [`requirements.yml`](./requirements.yml) for all collection dependencies.

To install all dependencies, run:

```bash
ansible-galaxy install -r requirements.yml
```

## Example Playbook
```yml
    - hosts: servers
      roles:
         - role: serversideup.spin.docker_swarm
```

## Adding a Swarm Manager
In order to create a new swarm, you must have a group in your inventory called `swarm_managers`. This group should contain all of the hosts that you want to be managers. You can have as many managers as you want, but you must have at least one.