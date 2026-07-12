variable "storage_account_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "allowed_subnet_ids" {
  description = "Subnets allowed through the storage firewall."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
