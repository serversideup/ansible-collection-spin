# Spin Deploy Ansible Role
Deploy to Docker Swarm servers over SSH without the headaches of Docker Registries or CI/CD.

## Requirements

You must have a server deployed and provisioned already with `spin provision`.

## Example Playbook
```yml
    - hosts: servers
      roles:
         - role: serversideup.spin.deploy
```