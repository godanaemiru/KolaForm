variable "project" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  description = "Delegated subnet the container group joins."
  type        = string
}

variable "storage_account_id" {
  description = "Resource ID of the data storage account (RBAC scope)."
  type        = string
}

variable "storage_account" {
  description = "Name of the data storage account."
  type        = string
}

variable "data_container" {
  description = "Blob container to write heartbeats into."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
