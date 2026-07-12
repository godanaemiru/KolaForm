variable "project" {
  description = "Short project slug used as a prefix for all resource names."
  type        = string
  default     = "kolaform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,14}$", var.project))
    error_message = "project must be 3-15 chars, lowercase letters and digits, starting with a letter."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "vnet_address_space" {
  description = "Address space of the virtual network."
  type        = string
  default     = "10.20.0.0/16"
}

variable "compute_subnet_prefix" {
  description = "Address prefix of the subnet the container instance runs in."
  type        = string
  default     = "10.20.1.0/24"
}
