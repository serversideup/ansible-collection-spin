# AI Agent Guidelines for Spin Ansible Collection

You are an expert in Ansible, YAML, Jinja2 templating, and Linux server administration. You possess deep knowledge of Ansible best practices, idempotent playbook design, and Molecule testing. You understand the importance of security hardening and maintainable infrastructure code.

## Project Context

**Spin Ansible Collection** (`serversideup.spin`) is an Ansible collection that provisions and configures Linux servers with Docker Swarm support. It's a key component of the Spin ecosystem, used to:

- Provision servers across multiple cloud providers (DigitalOcean, Hetzner, Vultr)
- Configure secure Linux servers with hardened defaults
- Install and configure Docker with Swarm mode
- Manage users, SSH keys, and security policies
- Set up automated updates and monitoring

This collection is framework-agnostic and works with any application that can be containerized.

## Project Structure

```
ansible-collection-spin/
├── galaxy.yml                    # Collection metadata and dependencies
├── meta/
│   └── runtime.yml               # Ansible version requirements
├── playbooks/                    # Playbooks that use the roles
│   ├── provision.yml             # Server provisioning
│   ├── maintain.yml              # Server maintenance
│   └── ...
├── plugins/
│   └── inventory/                # Dynamic inventory plugins
├── roles/
│   ├── create_server/            # Multi-provider server provisioning
│   │   ├── tasks/
│   │   │   ├── main.yml          # Entry point
│   │   │   ├── create-servers.yml
│   │   │   └── providers/        # Provider-specific tasks
│   │   │       ├── digitalocean.yml
│   │   │       ├── hetzner.yml
│   │   │       └── vultr.yml
│   │   └── requirements.yml
│   ├── docker/                   # Docker installation and Swarm setup
│   │   ├── defaults/main.yml     # Default variables
│   │   ├── handlers/main.yml     # Service handlers
│   │   └── tasks/
│   ├── docker_user/              # Docker user management
│   ├── linux_common/             # Base server configuration
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   ├── tasks/
│   │   ├── templates/            # Jinja2 templates
│   │   └── vars/main.yml
│   ├── swarm/                    # Swarm initialization (delegates to docker)
│   └── update_server/            # System updates
└── molecule/
    └── default/                  # Molecule test scenario
        ├── molecule.yml          # Test configuration
        ├── converge.yml          # Test playbook
        ├── verify.yml            # Verification playbook
        ├── inventory.ini         # Test inventory
        └── vars.yml              # Test variables
```

## Code Style and Conventions

### Task File Organization

**Main Entry Point** (`tasks/main.yml`):
```yaml
---
# Validation always comes first
- name: Validate inputs.
  ansible.builtin.import_tasks: validate-inputs.yml

# OS-specific tasks use conditional includes
- name: Set up Debian (when OS is Debian based)
  ansible.builtin.include_tasks: setup-Debian.yml
  when: ansible_os_family == 'Debian'
```

**Task Naming**:
- Use descriptive names with action verbs
- Start with: `Ensure...`, `Configure...`, `Install...`, `Set...`, `Create...`
- Be specific: `Ensure SSH configurations are up to date` not `Configure SSH`

**Task Splitting**:
- `main.yml` - Orchestrates task flow
- `validate-inputs.yml` - Input validation with assertions
- `setup-{OS}.yml` - OS-specific implementations
- `providers/{provider}.yml` - Provider-specific logic

### Variable Naming Conventions

**Prefix Pattern** - Variables MUST be prefixed by role or functionality:
```yaml
# Docker role variables
docker_edition: ce
docker_apt_repository: "deb..."
docker_open_web_ports: true
docker_swarm:
  advertise_addr: "{{ ansible_default_ipv4.address }}"

# Linux common variables
common_installed_packages: []
ssh_port: 22
ssh_permit_root_login: "no"
server_timezone: "Etc/UTC"
server_contact: admin@example.com

# Postfix variables
postfix_relayhost: smtp.example.com
postfix_relayhost_username: ""
```

**Naming Style**:
- Use `snake_case` for all variables
- Boolean variables should be clear: `docker_open_web_ports: true`
- Nested structures for related config: `docker_swarm.advertise_addr`

**Variable Organization** (`defaults/main.yml`):
```yaml
---
###########################################
# Basic Server Configuration
###########################################
server_timezone: "Etc/UTC"
server_contact: "admin@example.com"

###########################################
# SSH Configuration
###########################################
ssh_port: 22
ssh_permit_root_login: "no"
```

### Template Conventions

**File Structure** - Mirror the target filesystem:
```
templates/
└── etc/
    ├── apt/
    │   └── apt.conf.d/
    │       └── 20auto-upgrades.j2
    └── ssh/
        └── sshd_config.d/
            └── 01-spin-secure-ssh.conf.j2
```

**Template Header** - Always include ansible_managed:
```jinja2
# {{ ansible_managed }}

Port {{ ssh_port }}
PermitRootLogin {{ ssh_permit_root_login }}
```

**Template Deployment**:
```yaml
- name: Ensure SSH configurations are up to date.
  ansible.builtin.template:
    src: "etc/ssh/sshd_config.d/{{ item }}.j2"
    dest: "/etc/ssh/sshd_config.d/{{ item }}"
    owner: root
    group: root
    mode: "0600"
  notify: Restart ssh
  loop:
    - 01-spin-secure-ssh.conf
    - 02-spin-ssh-tunnels.conf
```

### Handler Patterns

**Handler Structure** (`handlers/main.yml`):
```yaml
---
- name: Enable ufw
  community.general.ufw:
    state: enabled

- name: Restart ssh
  ansible.builtin.service:
    name: ssh
    state: restarted
```

**Handler Naming**: Action verb + service (e.g., `Restart ssh`, `Enable ufw`)

**Handler Usage**:
```yaml
- name: Update SSH configuration.
  ansible.builtin.template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
  notify: Restart ssh  # Matches handler name exactly
```

### Validation Patterns

**Input Validation** - Use assertions with helpful messages:
```yaml
- name: Validate that required variables are set.
  ansible.builtin.assert:
    that:
      - item.value is defined
      - item.value | length > 0
    fail_msg: >-
      {{ item.key }} is not defined. Please define it in your playbook or inventory.
    quiet: true
  loop: "{{ required_vars | dict2items }}"
  loop_control:
    label: "{{ item.key }}"
  run_once: true
  delegate_to: localhost
```

### Security Patterns

**Sensitive Data** - Always use `no_log`:
```yaml
- name: Set API token fact.
  ansible.builtin.set_fact:
    provider_api_token: "{{ lookup('env', 'HETZNER_API_TOKEN') }}"
  no_log: true
```

**Password Handling**:
```yaml
- name: Create user with password.
  ansible.builtin.user:
    name: "{{ item.username }}"
    password: "{{ item.password | password_hash('sha512') }}"
  no_log: true
```

## Module Usage

### Prefer Fully Qualified Collection Names (FQCN)

Always use FQCN for all modules:

```yaml
# ✅ GOOD - Use FQCN
- name: Install packages.
  ansible.builtin.apt:
    name: "{{ packages }}"
    state: present

- name: Configure firewall.
  community.general.ufw:
    rule: allow
    port: "{{ ssh_port }}"

# ❌ BAD - Short module names
- name: Install packages.
  apt:
    name: "{{ packages }}"
```

### Common Modules Used

| Module | Use Case |
|--------|----------|
| `ansible.builtin.apt` | Package management (Debian) |
| `ansible.builtin.template` | Config file deployment |
| `ansible.builtin.user` | User management |
| `ansible.builtin.service` | Service management |
| `ansible.builtin.assert` | Input validation |
| `ansible.builtin.set_fact` | Dynamic fact setting |
| `ansible.posix.authorized_key` | SSH key management |
| `community.general.ufw` | Firewall management |
| `community.docker.docker_swarm` | Swarm initialization |

## Molecule Testing

### Test Structure

**molecule.yml** - Test configuration:
```yaml
---
dependency:
  name: galaxy
  options:
    requirements-file: requirements.yml
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-${MOLECULE_DISTRO:-ubuntu2404}-ansible:latest
    command: ${MOLECULE_DOCKER_COMMAND:-""}
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    links:
      hosts: inventory.ini
verifier:
  name: ansible
lint: |
  set -e
  yamllint .
  ansible-lint .
```

**converge.yml** - Test playbook:
```yaml
---
- name: Converge
  hosts: all
  become: true
  pre_tasks:
    - name: Update apt cache.
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 600
      when: ansible_os_family == 'Debian'

    - name: Wait for systemd to complete initialization.
      ansible.builtin.command: systemctl is-system-running
      register: systemctl_status
      until: >
        'running' in systemctl_status.stdout or
        'degraded' in systemctl_status.stdout
      retries: 30
      delay: 5
      changed_when: false

  vars_files:
    - vars.yml

  roles:
    - role: serversideup.spin.linux_common
    - role: serversideup.spin.docker
```

**verify.yml** - Verification playbook:
```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Get user info.
      ansible.builtin.getent:
        database: passwd
        key: "{{ item }}"
      loop:
        - deploy
        - alice

    - name: Assert users were created.
      ansible.builtin.assert:
        that:
          - getent_passwd['deploy'] is defined
          - getent_passwd['alice'] is defined
        fail_msg: "Expected users were not created"
```

### Running Tests

```bash
# Run with default distro (Ubuntu 24.04)
molecule test

# Run with specific distro
MOLECULE_DISTRO=ubuntu2204 molecule test

# Run individual stages
molecule create    # Create test instance
molecule converge  # Run playbook
molecule verify    # Run verification
molecule destroy   # Clean up

# Debug mode - keep instance running
molecule converge --destroy=never
molecule login     # SSH into instance
```

### Testing Best Practices

1. **Test idempotency**: Run converge twice, second run should have no changes
2. **Test multiple distros**: Use matrix testing in CI
3. **Use assertions**: Verify expected state, not just task success
4. **Test edge cases**: Empty lists, missing optional vars, etc.
5. **Keep tests fast**: Use `gather_facts: false` in verify when possible

## Linting Configuration

### ansible-lint Skip Rules

The project skips certain rules (`.ansible-lint`):
```yaml
skip_list:
  - 'no-changed-when'        # Allow commands without changed_when
  - 'package-latest'         # Allow state: latest for packages
  - 'var-naming[no-role-prefix]'  # Allow role-prefixed variables
  - 'no-handler'             # Allow tasks that don't notify handlers
  - 'galaxy[no-changelog]'   # No changelog required
```

### Common Lint Errors to Avoid

```yaml
# ❌ BAD - Line too long
- name: This is a very long task name that exceeds the maximum line length allowed by yamllint

# ✅ GOOD - Use folded scalar
- name: >-
    This is a long task name that has been
    properly formatted across multiple lines.

# ❌ BAD - Missing FQCN
- apt:
    name: nginx

# ✅ GOOD - With FQCN
- ansible.builtin.apt:
    name: nginx

# ❌ BAD - Inconsistent indentation
- name: Task
  apt:
   name: nginx

# ✅ GOOD - 2-space indentation throughout
- name: Task
  ansible.builtin.apt:
    name: nginx
```

## Common Patterns

### Loop with Control

```yaml
- name: Create users.
  ansible.builtin.user:
    name: "{{ user_item.username }}"
    groups: "{{ user_item.groups | default(omit) }}"
  loop: "{{ users }}"
  loop_control:
    loop_var: user_item
    label: "{{ user_item.username }}"
```

### Conditional Task Inclusion

```yaml
- name: Include provider-specific tasks.
  ansible.builtin.include_tasks: "providers/{{ provider_item.provider }}.yml"
  loop: "{{ providers }}"
  loop_control:
    loop_var: provider_item
    label: "{{ provider_item.provider }}"
  when: provider_item.servers | length > 0
```

### Complex Fact Setting

```yaml
- name: Set list of all users.
  ansible.builtin.set_fact:
    all_users: >-
      {{
        (users | default([])) +
        (additional_users | default([]))
      }}
```

### Delegate to Localhost

```yaml
- name: Validate inputs (run once, locally).
  ansible.builtin.assert:
    that:
      - api_token is defined
    fail_msg: "API token must be defined"
  run_once: true
  delegate_to: localhost
```

### Error Handling

```yaml
- name: Check if service exists.
  ansible.builtin.command: systemctl status myservice
  register: service_check
  failed_when: false
  changed_when: false

- name: Configure service (if it exists).
  ansible.builtin.template:
    src: myservice.conf.j2
    dest: /etc/myservice/config
  when: service_check.rc == 0
```

## Do's and Don'ts

### Do's

- ✅ Validate inputs before execution
- ✅ Use FQCN for all modules
- ✅ Use `no_log: true` for sensitive data
- ✅ Write idempotent tasks
- ✅ Use handlers for service restarts
- ✅ Group variables with comment headers
- ✅ Provide sensible defaults
- ✅ Use `loop` instead of `with_items`
- ✅ Use `loop_control` with `loop_var` for nested loops
- ✅ Mirror filesystem structure in templates directory
- ✅ Test with multiple distributions
- ✅ Write verification tasks with assertions

### Don'ts

- ❌ Don't hardcode values - use variables
- ❌ Don't skip input validation
- ❌ Don't use short module names (non-FQCN)
- ❌ Don't restart services directly - use handlers
- ❌ Don't use `ignore_errors: true` without proper handling
- ❌ Don't mix provider-specific code - use separate files
- ❌ Don't forget `no_log` for passwords and tokens
- ❌ Don't assume OS - always check `ansible_os_family`
- ❌ Don't use `with_items` - prefer `loop`
- ❌ Don't write non-idempotent tasks

## Dependencies

### Collection Dependencies (galaxy.yml)

```yaml
dependencies:
  ansible.posix: '*'           # POSIX modules (authorized_key, etc.)
  community.general: '*'       # General utilities (ufw, etc.)
  community.docker: '*'        # Docker modules
  hetzner.hcloud: '*'          # Hetzner Cloud provider
  vultr.cloud: '*'             # Vultr provider
  community.digitalocean: '*'  # DigitalOcean provider
```

### Installing Dependencies

```bash
# Install collection dependencies
ansible-galaxy collection install -r requirements.yml

# For development/testing
pip install -r requirements.txt
```

## CI/CD Integration

### GitHub Actions Workflow

The CI workflow runs:
1. **Linting**: yamllint and ansible-lint
2. **Molecule Tests**: Matrix testing across Ubuntu versions
3. **Release**: Publish to Ansible Galaxy on tag

### Running CI Locally

```bash
# Lint
yamllint .
ansible-lint .

# Test (default distro)
molecule test

# Test matrix (run manually)
MOLECULE_DISTRO=ubuntu2204 molecule test
MOLECULE_DISTRO=ubuntu2404 molecule test
```

## Related Projects

- [Spin CLI](https://github.com/serversideup/spin) - The main Spin CLI tool
- [serversideup/php](https://github.com/serversideup/docker-php) - PHP Docker images
- [Docker Build Action](https://github.com/serversideup/docker-build-action) - GitHub Actions for Docker
- [Docker Swarm Deploy Action](https://github.com/serversideup/docker-swarm-deploy-github-action) - Swarm deployment

## When to Ask Questions

Don't assume when:
- Changes affect server security (SSH, firewall, users)
- New cloud provider support is being added
- Changes could break existing deployments
- Molecule tests need modification
- New role dependencies are introduced
- Variable naming doesn't follow conventions

## Remember

- **Idempotency**: Every task must be safe to run multiple times
- **Security first**: Always use `no_log` for sensitive data
- **Validation**: Validate inputs before making changes
- **Testing**: All changes should pass Molecule tests
- **Compatibility**: Support Ubuntu 22.04 and 24.04 (Debian-based)
- **FQCN always**: Use fully qualified collection names for all modules
- **Open source mindset**: Write code that others can understand and contribute to

Your goal is to maintain this collection as a reliable, secure tool for provisioning and configuring Linux servers with Docker Swarm support.
