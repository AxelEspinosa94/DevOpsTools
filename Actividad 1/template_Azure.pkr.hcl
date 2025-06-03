packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 1.0"
    }
  }
}

variable "location"          { default = "eastus2" }
variable "resource_group"    { default = "rg-packer-images" }
variable "image_name"        { default = "adc-node-nginx-{{timestamp}}" }

variable "install_nginx"     { default = "dependencies/Nginx-installation.sh" }
variable "install_node"      { default = "dependencies/Node-installation.sh"  }
variable "deploy_app"        { default = "dependencies/deploy_app.sh"         }

source "azure-arm" "ubuntu" {
  client_id             = env("ARM_CLIENT_ID")
  client_secret         = env("ARM_CLIENT_SECRET")
  tenant_id             = env("ARM_TENANT_ID")
  subscription_id       = env("ARM_SUBSCRIPTION_ID")

  managed_image_resource_group_name = var.resource_group
  managed_image_name                = var.image_name

  location      = var.location
  vm_size       = "Standard_B1s"
  os_type       = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_sku       = "20_04-lts-gen2"

  # use SSH key of the current user
  ssh_username          = "azureuser"
}

build {
  sources = ["source.azure-arm.ubuntu"]

  provisioner "shell" {
    script          = var.install_nginx
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = var.install_node
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = var.deploy_app
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  post-processor "manifest" {}   # writes packer-manifest.json
}