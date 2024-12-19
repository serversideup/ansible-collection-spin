# Server Creation Ansible Role

Easily create and configure servers across multiple cloud providers (DigitalOcean, Hetzner, and Vultr). This role handles server provisioning, SSH key management, and firewall configuration automatically.

## Requirements

For now, this role supports the following cloud providers:
- DigitalOcean
- Hetzner Cloud
- Vultr

You'll need API credentials for whichever provider you choose to use.

## Role Variables

The role expects server configurations to be defined in your playbook or inventory. Here's an example structure:

```yaml
servers:
  - server_name: "web-1"
    hardware_profile: "standard-2gb"  # Must match a profile in hardware_profiles
    environment: "production"         # Must match an environment name
    backups: true                    # Optional, defaults to true

hardware_profiles:
  - name: "standard-2gb"
    provider: "digitalocean"         # One of: digitalocean, hetzner, vultr
    profile_config:
      region: "nyc1"                 # Provider-specific configuration
      size: "s-2vcpu-2gb"           # Varies by provider
      image: "ubuntu-22-04-x64"

providers:
  - name: "digitalocean"
    api_token: "your_token_here"     # Can also use DO_API_TOKEN env var
```

## Environment Variables

The role supports the following environment variables for API authentication:

- `DO_API_TOKEN` - DigitalOcean API token
- `HCLOUD_TOKEN` - Hetzner Cloud API token
- `VULTR_API_KEY` - Vultr API key

## Dependencies

Required Ansible collections (see `requirements.yml`):
- `hetzner.hcloud`
- `vultr.cloud`
- `community.digitalocean`

To install dependencies:
```bash
ansible-galaxy install -r requirements.yml
```

## Features

- Multi-provider support (DigitalOcean, Hetzner, Vultr)
- Automatic SSH key management
- Standard firewall configuration across providers
- IPv4 and IPv6 support
- Configurable hardware profiles
- Environment tagging
- Backup configuration

## Example Playbook

```yaml
- hosts: localhost
  roles:
    - role: create_server
  vars:
    servers:
      - server_name: "web-1"
        hardware_profile: "standard-2gb"
        environment: "production"
    
    hardware_profiles:
      - name: "standard-2gb"
        provider: "digitalocean"
        profile_config:
          region: "nyc1"
          size: "s-2vcpu-2gb"
          image: "ubuntu-22-04-x64"
```

## Firewall Configuration

The role automatically configures a standard firewall for web applications with the following rules:

- ICMP (ping) from anywhere
- SSH (port 22) from anywhere
- HTTP (port 80) from anywhere
- HTTPS (port 443) from anywhere
- SSH tunnel (port 2222) from anywhere
- All outbound traffic allowed 