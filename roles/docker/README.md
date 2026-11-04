# Docker Ansible Role

Deploy and maintain Docker servers easily. This role was inspired by [Jeff Geerling](https://github.com/geerlingguy), but expanded to support Docker Swarm. Please support his amazing work!

## Requirements

For now, this project focuses on supporting **Ubuntu 22.04+** only. Choose any host that you'd like. All this role needs is an SSH connection to a user that has `sudo` privileges.

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
docker_apt_arch: "{{ 'arm64' if ansible_facts['architecture'] == 'aarch64' else 'amd64' }}"
docker_apt_ignore_key_error: true
docker_apt_gpg_key: "{{ docker_repo_url }}/{{ ansible_facts['distribution'] | lower }}/gpg"
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

## Docker daemon configuration
The role merges `docker_daemon_options` into `/etc/docker/daemon.json`. Keys that other roles or people added to that file stay in place, and keys set in `docker_daemon_options` win when both set the same key.

By default the role uses Docker's recommended [`local` logging driver](https://docs.docker.com/engine/logging/drivers/local/), which keeps 5 compressed files of 20 MB per container so logs can't fill the disk.

```yml
docker_daemon_options:
  log-driver: "local"

# Expose Docker engine and Swarm metrics to a local Prometheus scraper (off by default).
docker_metrics_addr: "127.0.0.1:9323"

# "restarted" applies daemon.json changes right away. "started" waits for the next restart you schedule.
docker_restart_handler_state: restarted
```

Docker only reads `daemon.json` when it starts, so the role restarts Docker when the file changes. A restart stops every container on the host, and Swarm services and containers without a restart policy only come back once Swarm or you start them again. On servers that are already running, set `docker_restart_handler_state: "started"` and restart Docker yourself during a maintenance window. On a new server the file is written before Docker is installed, so Docker's first start already uses it.

Logging changes only apply to containers created after the restart. Existing containers keep their old logging settings until they are re-created, for example by your next deployment.

When Docker is already installed, the role checks the merged file with `dockerd --validate` before writing it, so a bad option can't stop Docker from starting.

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
         - role: serversideup.spin.docker
```

## Adding a Docker Swarm Manager
In order to create a new swarm, you must have a group in your inventory called `swarm_managers`. This group should contain all of the hosts that you want to be managers. You can have as many managers as you want, but you must have at least one.