############################################################
# Variables
############################################################

variable "project_name" {
  description = "Short name for this nginx demo project"
  type        = string
  default     = "nginx-demo"
}

variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
  default     = "rg-nginx-demo"
}

variable "location" {
  description = "Azure region to deploy to"
  type        = string
  default     = "westeurope"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Path to your SSH public key (e.g. ~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

