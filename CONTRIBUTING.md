# Contributing Guidelines
The Spin Ansible Collection is an open-source project that aims to provide a seamless and efficient way to provision and manage servers. This collection is designed to work seamlessly with the Spin command-line tool to automate server setup, configuration, and deployment.

## Preparing a virtual python environment
You can use [`pipx`](https://pipx.pypa.io/stable/) to install `virtualenv` and create a virtual environment.

```bash
pipx install virtualenv
``` 

Create a virtual environment in your home directory:

```bash
virtualenv ~/.py
```

Activate the virtual environment:

```bash
source ~/.py/bin/activate
```

If you want to make the virtual environment available to all users, you can activate it in your `.bashrc` or `.zshrc` file.

```bash
source ~/.py/bin/activate
```

Use the `pip3` command to install Ansible and Molecule:

```bash
pip3 install -r requirements.txt
```

## Running tests
We use [Molecule](https://molecule.readthedocs.io/en/latest/) to test the role.

```bash
molecule test
```

## Advanced usage
Instead of running `molecule test` to run the tests (which will destroy and recreate the test environment), you can use the following commands to test the role in a container:

```bash
molecule create # Builds the container
molecule converge # Runs the playbook
molecule verify # Runs the tests
molecule destroy # Destroys the container
```