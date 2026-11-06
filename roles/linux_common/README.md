Linux Common
=========

 A simple playbook to secure your server, prep your users, and prepare your server for other uses. 

Requirements
------------

For now, this project focuses on supporting **Ubuntu 22.04 LTS, 24.04 LTS, 26.04 LTS, and Debian 13** only. Choose any host that you'd like. All this role needs is an SSH connection to a user that has `sudo` privileges.

Role Variables
--------------

You can find all variables organized and documented in `defaults/main.yml`. Feel free to override any variable of your choice.

```yml
---
###########################################
# Basic Server Configuration
###########################################
server_timezone: "Etc/UTC"
server_contact: changeme@example.com

# SSH
ssh_port: "22"

## Sudo
## Set to true to let sudo users run commands without a password.
## When false, every sudo user must have a password set.
use_passwordless_sudo: false

## Email Notifications
postfix_hostname: "{{ inventory_hostname }}"

## Set variables below to enable external SMTP relay
# postfix_relayhost: "smtp.example.com"
# postfix_relayhost_port: "587"
# postfix_relayhost_username: "myusername"
# postfix_relayhost_password: "mysupersecretpassword"

###########################################
# Install Packages Configuration
###########################################

# Base packages that will always be installed
common_installed_packages:
  - cron
  - curl
  - figlet
  - fail2ban
  - git
  - htop
  - logrotate
  - mailutils
  - ncdu
  - ntp
  - python3-minimal
  - python3-pip
  - ssh
  - tzdata
  - ufw
  - unattended-upgrades
  - unzip
  - wget
  - zip

# Additional packages that users can define
common_additional_packages:
  - python3-jsondiff
  - python3-yaml

# PIP - Python Packages (examples below if you need them)
# pip_packages:
#   - jsondiff
#   - pyyaml

# APT - Automatic Update Configuration
apt_periodic_update_package_lists: "1"
apt_periodic_download_upgradeable_packages: "1"
apt_periodic_autoclean_interval: "7"
apt_periodic_unattended_upgrade: "1"

# Unattended Upgrades - Email Notifications
# Options: "always", "only-on-error", "on-change"
unattended_upgrade_mail_report: "only-on-error"

# Unattended Upgrades - Automatic Reboots
# Reboot automatically when an update needs it (e.g. a kernel update).
# Off by default so servers never reboot without you choosing it.
unattended_upgrade_automatic_reboot: false
# "now" or "HH:MM" in the server's local time
unattended_upgrade_automatic_reboot_time: "04:00"

###########################################
# Audit Logging (auditd)
###########################################
## Records changes to accounts, sudo, SSH, cron, and systemd units, programs run from
## temporary folders, and every command a logged-in user runs as root (including with sudo).
## Off by default. Logs stay in /var/log/audit, so ship them off the server if you want
## to keep them as evidence after a breach.
auditd_enabled: false
## Size of each log file in MB, and how many to keep before the oldest is deleted
auditd_max_log_file: 50
auditd_num_logs: 10

###########################################
# CrowdSec (replaces fail2ban)
###########################################
## Detects attacks in your logs and blocks the attacking IPs at the firewall, including
## traffic to Docker containers. When on, fail2ban is turned off. Off by default.
crowdsec_enabled: false
## Share attack signals (attacker IP, which detection fired, and when) with CrowdSec to
## get their community blocklist in return. Off by default for privacy, such as GDPR.
crowdsec_share_signals: false
## HTTP detections (scans, brute force, and exploit attempts against web apps) only log
## what they would block until you set this to false. SSH detections always block.
crowdsec_http_simulation: true
## IPs or CIDR ranges that are never blocked, even by the community blocklist. Adding one
## also lifts any ban it already has. Private networks are always allowed.
crowdsec_allowlist: []
## Docker containers whose logs are Traefik access logs, as regular expressions. The default
## matches Compose (traefik) and Swarm (mystack_traefik.1.abc123) names.
crowdsec_traefik_containers:
  - ".*traefik.*"

###########################################
# Fun Terminal Customizations
###########################################
motd_header_text: "ServerSideUp"
motd_header_text_color: '\e[38;5;255m'
motd_header_background_color: '\e[48;5;34m'
motd_hostname_text_color: '\e[38;5;202m'
motd_services:
  - ufw
  - fail2ban
  - postfix

##############################################################
# Users
##############################################################

### Use the template below to set users and their authorized keys
## Passwords must be set with an encrypted hash. To do this, see the Ansible FAQ
## https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#how-do-i-generate-encrypted-passwords-for-the-user-module

# users:
#   - username: alice
#     name: Alice Smith
#     state: present
#     groups: ['adm','sudo']
#     password: "$6$mysecretsalt$qJbapG68nyRab3gxvKWPUcs2g3t0oMHSHMnSKecYNpSi3CuZm.GbBqXO8BE6EI6P1JUefhA0qvD7b5LSh./PU1"
#     shell: "/bin/bash"
#     authorized_keys:
#       - public_key: "ssh-ed25519 AAAAC3NzaC1lmyfakeublickeyMVIzwQXBzxxD9b8Erd1FKVvu alice"

#   - username: bob
#     name: Bob Smith
#     state: present
#     password: "$6$mysecretsalt$qJbapG68nyRab3gxvKWPUcs2g3t0oMHSHMnSKecYNpSi3CuZm.GbBqXO8BE6EI6P1JUefhA0qvD7b5LSh./PU1"
#     groups: ['adm','sudo']
#     shell: "/bin/bash"
#     authorized_keys:
#       - public_key: "ssh-ed25519 AAAAC3NzaC1anotherfakekeyIMVIzwQXBzxxD9b8Erd1FKVvu bob"

### Additional users
## You can also set additional users (great if you're working with contractors or clients on certain groups of servers)
## These users will be flattened into the users list (if you set any settings below)

# additional_users:
#   - username: charlie
#     name: Charlie Smith
#     state: present
#     groups: ['adm','sudo']
#     password: "$6$mysecretsalt$qJbapG68nyRab3gxvKWPUcs2g3t0oMHSHMnSKecYNpSi3CuZm.GbBqXO8BE6EI6P1JUefhA0qvD7b5LSh./PU1"
#     shell: "/bin/bash"
#     authorized_keys:
#       - public_key: "ssh-ed25519 AAAAC3NzaC1lmyfakeublickeyMVIzwQXBzxxD9b8Erd1FKVvu alice"

#   - username: dana
#     name: Dana Smith
#     state: present
#     password: "$6$mysecretsalt$qJbapG68nyRab3gxvKWPUcs2g3t0oMHSHMnSKecYNpSi3CuZm.GbBqXO8BE6EI6P1JUefhA0qvD7b5LSh./PU1"
#     groups: ['adm','sudo']
#     shell: "/bin/bash"
#     authorized_keys:
#       - public_key: "ssh-ed25519 AAAAC3NzaC1anotherfakekeyIMVIzwQXBzxxD9b8Erd1FKVvu bob"
```

Dependencies
------------
See [`requirements.yml`](./requirements.yml) for all collection dependencies.

To install all dependencies, run:

```bash
ansible-galaxy install -r requirements.yml
```

Example Playbook
----------------

```yml
    - hosts: servers
      vars:
        # Optional: use your inventory names as system hostnames.
        server_hostname: "{{ inventory_hostname }}"
      roles:
         - { role: serversideup.spin.linux_common, server_timezone: 'America/Chicago' }
```
