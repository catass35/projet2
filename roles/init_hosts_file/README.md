# init_hosts_file

Ansible role to update the `/etc/hosts` file on all managed nodes with the IP addresses and hostnames of all the servers defined in the Ansible inventory.

## Requirements

- Ansible 2.9 or later
- A configured inventory file with host IP addresses and aliases
- Python installed on the managed nodes

## Role Variables

This role does not have any variables.

## Dependencies

No dependencies on other roles.

## Example Playbook

Here is an example of how to use this role in a playbook:

```yaml
---
- name: Initialize hosts file
  hosts: all
  become: yes
  roles:
    - init_hosts_file
