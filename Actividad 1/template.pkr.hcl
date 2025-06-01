packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.0"
    }
  }
}

# Definición de variables
variable "aws_region" {
    type    = string
    default = "XXXX"
}

variable "instance_type" {
    type    = string
    default = "t2.micro"
}

# Variables para los scripts de provisión
variable "install_nginx_script" {
  type    = string
  default = "dependencies/Nginx-installation.sh"
}

variable "install_node_script" {
  type    = string
  default = "dependencies/Node-installation.sh"
}

variable "deploy_app_script" {
  type    = string
  default = "dependencies/deploy_app.sh"
}

# Fuente de la AMI en AWS
source "amazon-ebs" "ubuntu" {
  region         = var.aws_region
  instance_type  = var.instance_type
  ssh_username   = "ubuntu"
  ami_name       = "ADC-nodejs-nginx-app-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["XXXX"]
    most_recent = true
  }

  # Etiquetas para identificar la imagen
  tags = {
    Name        = "NodeJS-Nginx-App"
    Environment = "Production"
    Builder     = "Packer"
  }
}

# Sección de construcción con provisionadores utilizando los scripts externos
build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    script = var.install_nginx_script
  }

  provisioner "shell" {
    script = var.install_node_script
  }

  provisioner "shell" {
    script = var.deploy_app_script
  }
}