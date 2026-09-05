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

variable "vm_size" {
  description = "Size used for both Windows Server VMs"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Local administrator username for the VMs"
  type        = string
  default     = "labadmin"
}

variable "admin_password" {
  description = "Local administrator password for the VMs"
  type        = string
  sensitive   = true
}