[![CI](https://github.com/de-it-krachten/ansible-role-duplicity/workflows/CI/badge.svg?event=push)](https://github.com/de-it-krachten/ansible-role-duplicity/actions?query=workflow%3ACI)


# ansible-role-duplicity

<basic role description>



## Dependencies

#### Roles
None

#### Collections
None

## Platforms

Supported platforms

- Red Hat Enterprise Linux 8<sup>1</sup>
- Red Hat Enterprise Linux 9<sup>1</sup>
- RockyLinux 8
- RockyLinux 9
- OracleLinux 8
- OracleLinux 9
- AlmaLinux 8
- AlmaLinux 9
- SUSE Linux Enterprise 15<sup>1</sup>
- openSUSE Leap 15
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)
- Debian 13 (Trixie)
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Fedora 41
- Fedora 42

Note:
<sup>1</sup> : no automated testing is performed on these platforms

## Role Variables
### defaults/main.yml
<pre><code>
# List of required duplicity packages
duplicity_packages:
  - duplicity
</pre></code>

### defaults/family-Debian.yml
<pre><code>
# List of optional duplicity packages
duplicity_packages_optional:
  - par2
</pre></code>

### defaults/family-RedHat.yml
<pre><code>
# List of optional duplicity packages
duplicity_packages_optional:
  - par2cmdline
</pre></code>

### defaults/family-Suse.yml
<pre><code>
# List of optional duplicity packages
duplicity_packages_optional:
  - par2
</pre></code>




## Example Playbook
### molecule/default/converge.yml
<pre><code>
- name: sample playbook for role 'duplicity'
  hosts: all
  become: 'yes'
  tasks:
    - name: Include role 'duplicity'
      ansible.builtin.include_role:
        name: duplicity
</pre></code>
