variable "pm_api_url" {
  type = string
  description = "Proxmox API URL"
}
variable "pm_user" {
  type = string
  description = "Proxmox API user. Uses <username>@<loginrealm> form"
}
variable "pm_password" {
  type = string
  description = "Proxmox API user password"
}
variable "pm_tls_insecure" {
  type = bool
  default = true
  description = "Sets if TLS connections can be insecure or not"
}
variable "vault_url" {
  type = string
  description = "Vault API URL"
}
variable "vault_user" {
  type = string
  description = "User that will authenticate to Vault to encrypt csr attributes"
}
variable "vault_password" {
  type = string
  description = "Password for vault_user"
}
variable "node_name" {
  type = string
  description = "The FQDN for your new VM."
}
variable "desc" {
  type = string
  default = "Provisioned by Terraform"
  description = "A description for your new VM."
}
variable "target_node" {
  type = string
  description = "The Proxmox hostname (not fqdn) that your VM will be created on."
}
variable "clone" {
  type = string
  description = "The name of a cloud-init template in your Proxmox cluster."
}
variable "bios" {
  type = string
  default = "seabios"
  description = "The type of BIOS to assign to new VM"
}
variable "onboot" {
  type = bool
  default = true
  description = "If this VM should start when the hypervisor boots up."
}
variable "agent" {
  type = number
  default = 0
  description = "If QEMU agent should be installed"
}
variable "full_clone" {
  type = bool
  default = true
  description = "If cloning, should new VM be a full or linked clone"
}
variable "memory" {
  type = number
  default = 512
  description = "Amount of memory to assign new VM in MB"
}
variable "disk" {
  type = object({
    id = number
    type = string
    storage = string
    storage_type = string
    size = number
  })
  default = {
    id = 0
    type = "scsi"
    storage = "local-lvm"
    storage_type = "lvm"
    size = 20
  }
  description = "Sets the disk on the VM. Params: id - disk number on vm; type - storage connection type; storage - storage name; storage_type - type of storage(lvm, rdb, etc.); size - size of disk in GB."
}
variable "cpu_cores" {
  type = number
  default = 1
  description = "Number of CPU cores to allocate to VM."
}
variable "cpu_sockets" {
  type = number
  default = 1
  description = "Number of CPU sockets to allocate to VM."
}
variable "network" {
  type = object({
    id = number
    model = string
    bridge = string
  })
  default = {
    id = 0
    model = "virtio"
    bridge = "vmbr0"
  }
  description = "Sets the NIC on the VM. Params: id - NIC id on vm; model - Model of virtual NIC; bridge - The bridge to assign the NIC to."
}
variable "node_ipv4_address" {
  type = string
  description = "The IPv4 address to assign the node sans subnet mask."
}
variable "node_subnet" {
  type = string
  default = "/24"
  description = "Slash-notation subnet mask for the VM."
}
variable "gateway_ipv4" {
  type = string
  description = "IPv4 address of the subnet gateway for the node."
}
variable "ssh_user" {
  type = string
  default = "root"
  description = "The user that will connect to the remote machine via SSH"
}
variable "ssh_private_key" {
  type = string
  description = "A SSH private key that the SSH user will use to authenticate to the machine"
}
variable "ssh_port" {
  type = number
  default = 22
  description = "The port on the node to use for SSH."
}
variable "pe_master_provision_url" {
  type = string
  default = "https://puppet:8140/packages/current/install.bash"
  description = "The URL provided by PE to install the Puppet agent."
}
provider "proxmox" {
  pm_api_url = var.pm_api_url
  pm_user = var.pm_user
  pm_password = var.pm_password
  pm_tls_insecure = var.pm_tls_insecure
}

/* Uses cloud-init options from Proxmox 5.2 */
resource "proxmox_vm_qemu" "puppet_node" {
  name = var.node_name
  desc = var.desc
  target_node = var.target_node
  clone = var.clone

  disk {
    id = var.disk.id
    type = var.disk.type
    storage = var.disk.storage
    storage_type = var.disk.storage_type
    size = var.disk.size
  }
  cores = var.cpu_cores
  sockets = var.cpu_sockets
  memory = var.memory
  network {
    id = var.network.id
    model = var.network.model
    bridge = var.network.bridge
  }
  ipconfig0 = "ip=${var.node_ipv4_address}${var.node_subnet},gw=${var.gateway_ipv4}"
  ssh_user = var.ssh_user
  ssh_private_key = var.ssh_private_key


  os_type = "cloud-init"

  provisioner "local-exec" {
    command = "./make_extensions_yaml.sh ${proxmox_vm_qemu.puppet_node.name} ${var.vault_url} ${var.vault_user} ${var.vault_password}"
  }

  ssh_forward_ip = var.node_ipv4_address

  connection {
    type = "ssh"
    user = var.ssh_user
    private_key = var.ssh_private_key
    host = var.node_ipv4_address
    port = var.ssh_port
  }

  provisioner "remote-exec" {
    inline = [
      "if [ ! -d /etc/puppetlabs/puppet ]; then mkdir -p /etc/puppetlabs/puppet; fi"
    ]
  }

  provisioner "file" {
    source = "./csr_attributes.yaml"
    destination = "/etc/puppetlabs/puppet/csr_attributes.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -k ${var.pe_master_provision_url} | sudo bash"
    ]
  }
}
