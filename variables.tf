variable "location" {
  description = "Azure region for the lab"
  type        = string
  default     = "canadacentral"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-adlab"
}

variable "windows_vm_size" {
  description = "Size for Windows Server VMs"
  type        = string
  default     = "Standard_B2s"
}

variable "linux_vm_size" {
  description = "Size for the Ansible controller"
  type        = string
  default     = "Standard_B1s"
}

variable "windows_admin_username" {
  description = "Local administrator for Windows VMs"
  type        = string
  default     = "labadmin"
}

variable "windows_admin_password" {
  description = "Local administrator password for Windows VMs"
  type        = string
  sensitive   = true
}

variable "linux_admin_username" {
  description = "Administrator username for ANSIBLE01"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key used to access ANSIBLE01"
  type        = string
}

variable "admin_source_cidr" {
  description = "Public IP/CIDR allowed to SSH to ANSIBLE01"
  type        = string
}