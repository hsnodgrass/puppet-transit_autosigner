# puppet-transit_autosigner

*This repo is a very early draft of this process / workflow and will continue to be updated.*

Use Vault's transit encryption endpoint to ensure a secure [policy-based autosigning](https://puppet.com/docs/puppet/latest/ssl_autosign.html#concept-9595) workflow when using Puppet Enterprise 2019.x. These same concepts can also be applied to Open Source Puppet, but the examples are geared towards PE.

## Overview

There are three pieces required for this workflow: PE 2019.x, a Hashicorp Vault server, and a provisioner that can interact with the new machine after creation (such as Terraform). This workflow uses Vault's "encryption as a service" to create an encrypted CSR attribute that is then decrypted during the autosigning process and compared against a known-value to see if the CSR should be signed.

## Example Code

The directories in this repo all contain example code for various workflows all based around the concept of using Vault transit encryption to facilitate autosigning. Please see the READMEs in each directory for more information.

## What's Going On

By integrating policy-based autosigning with Vault transit encryption and our provisioning process, we have created a fully-automated and secure policy-based autosigner that requires no other information besides a node name. This sounds awesome, but how does it actually work? The truth is, it's much more simple than it sounds.

### Vault Transit Encryption

One of Vault's many secrets engines, the transit secrets engine, offers what I have been calling "encryption as a service". When you enable the transit secret store, it does nothing right off the bat. However, once you add an encryption key to that backend, Vault creates two new API routes: `transit/encrypt/<keyname>` and `transit/decrypt/<keyname>`. Now, you can send data to `transit/encrypt/<keyname>` and recieve an encrypted version of the data back. This encrypted data can only be decrypted by sending it to `transit/decrypt/<keyname>`. Side note, data encrypted with the transit secrets engine must be base64 encoded.

More info about the [transit secret engine can be found here.](https://www.vaultproject.io/docs/secrets/transit/)

### Using Transit Encryption in an Autosigning Workflow

If you are familiar with Vault then you have probably already seen the coolest part (IMO) of the transit secret engine: the two distinct API endpoints. This allows for using Vault ACLs to grant encryption access and decryption access to separate Vault users. How it's used in autosigning is that access is granted only to the encryption endpoint for accounts provisioning nodes, while access is granted only to the decryption endpoint for the service account used in the autosigner script. We then encrypt the new node's hostname and save it to a `csr_attributes.yaml` file which bakes that encrypted hostname into the [CSR from a Puppet agent as a certificate extension](https://puppet.com/docs/puppet/latest/ssl_attributes_extensions.html). When the policy-based autosigner executes, it uses an account that has access to the decryption endpoint to decrypt our certificate extension and verify that it matches the node name that is baked into the CSR by default.

With this workflow you don't have to deal with pre-shared keys (a common autosigning solution) because the secret is the encryption and access to it. In order to get a CSR fraudulently signed, you would need to comprimise both the provisioner account and bake the encrypted hostname of the machine into the CSR. This is fairly secure, and what the examples show, but can easily be expanded upon.

## Making This More Robust

In the basic examples, the weak link is the single provisioner account. However, this can be made more robust. Below are a few examples on how to expand this solution.

### Two Accounts, Two Values to Compare

The most basic solution to this issue is to have mutiple accounts be involved in the provisioning process. Imagine a workflow like this:

* Provisioner service account `terraform` is used to encrypt the hostname.
* That encrypted hostname is stored in a [K/V secrets backend](https://www.vaultproject.io/docs/secrets/kv/kv-v2/) by another account, `terraform_kv`, that only has write access to that backend.
* During autosigning, the CSR attribute is decrypted and saved as a variable, `$csr_attr`, and the value from the K/V store is decrypted and saved as another variable, `$kv_attr`.
* Both `$csr_attr` and `$kv_attr` are compared against the plaintext hostname that is passed to the autosigner by default. If one doesn't match, the autosigner fails.

Examples of this workflow are coming soon.
