Linux Common
=========

 A simple playbook to secure your server, prep your users, and prepare your server for other uses. 

Requirements
------------

For now, this project focuses on supporting **Ubuntu 22.04** only. Choose any host that you'd like. All this role needs is an SSH connection to a user that has `sudo` privileges.

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
      roles:
         - { role: serversideup.spin.linux_common, server_timezone: 'America/Chicago' }
```