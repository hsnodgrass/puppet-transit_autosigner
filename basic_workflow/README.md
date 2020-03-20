# Basic Workflow

This directory contains example code for the most basic workflow that uses Vault transit encryption the policy-based autosigning process.

## Vault Setup

* First things first, you will need a Vault server. If you don't know much about Vault, start here and go all the way through: [https://learn.hashicorp.com/vault/getting-started/install]
* Enable the transit secrets engine and create a key for it.
  * Using Vault cli: `vault secrets enable transit`
  * Using Vault cli: `vault write -f transit/keys/puppet_autosigner`
    * Note: By default, transit keys use `aes256-gcm96` to encrypt values. This algorithm can [be configured.](https://www.vaultproject.io/api/secret/transit/index.html)
* Next, you will need to configure two accounts on that Vault server: `puppet` and `terraform`.
  * The first step to creating user accounts in Vault is to create the ACL policies they will use. Policy `.hcl` files are provided in `vault_files/user_policies`.
    * Using `provisioner.hcl`, create a policy called `provisioner`.
    * Using `puppet.hcl`, create a policy called `puppet`.
  * Now we can create the actual user accounts.
    * Create a user account `terraform` and assign it the policy `provisioner`
    * Create a user account `puppet` and assign it the policy `puppet`
    * Ensure both of these accounts can login to Vault via the username / password auth backend.

## PE Setup

* Copy `puppetmaster/opt/autosigner_vars` and `puppetmaster/opt/autosigner.sh` to your Puppet master at `/opt/autosigner_vars` and `/opt/autosigner.sh` respectively.
* Ensure both files are owned by root and executable. `chown root:root /opt/<file>` and `chmod +x /opt/<file>`
* Enable [policy-based autosigning](https://puppet.com/docs/puppet/latest/ssl_autosign.html#concept-9595)
  * In `puppet.conf`, set `autosign = /opt/autosigner.sh` in the `[master]` section.

You are now all set up to provision away. The script `provisioning/make_extensions_yaml.sh` will go through the process of creating a `csr_attributes.yaml` file with an encrypted hostname in the `challengePassword` extension. The terraform file `example_terraform/proxmox-test.tf` can provision nodes as long as you move it to your terraform directory and copy `make_extensions_yaml.sh` to the same directory. 

## A Note on Terraform

The terraform file provided is meant for use with [Proxmox, the open source hypervisor I use at home.](https://www.proxmox.com/en/proxmox-ve) However, everything at line 180 and below is where the real magic happens and none of that depends on using Proxmox.

### Why Don't You Use the Puppet Provisioner?

The Puppet provisioner that comes bundled with Terraform depends on [`puppet-autosign`](https://github.com/danieldreier/puppet-autosign). No big deal, I thought. I'll tell the provisioner that I don't want to use autosigning and just use it anyways. Turns out that's impossible because **if you choose to not use autosiging through the provisioner, by extension using puppet-autosign, the provisioner deletes any csr_attributes.yaml file that may be present before agent install.** Long story short, I can't use the provisioner and use this workflow.
