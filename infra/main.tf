# Stable random suffix so globally-unique names (storage accounts) don't
# collide across forks. Persisted in state, so names stay constant.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  suffix = random_string.suffix.result

  tags = {
    project    = var.project
    managed_by = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${var.project}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "./modules/network"

  project               = var.project
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  vnet_address_space    = var.vnet_address_space
  compute_subnet_prefix = var.compute_subnet_prefix
  tags                  = local.tags
}

module "data" {
  source = "./modules/data"

  storage_account_name = "kfdata${local.suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  allowed_subnet_ids   = [module.network.compute_subnet_id]
  tags                 = local.tags
}

module "compute" {
  source = "./modules/compute"

  project             = var.project
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.compute_subnet_id
  storage_account_id  = module.data.storage_account_id
  storage_account     = module.data.storage_account_name
  data_container      = module.data.container_name
  tags                = local.tags
}
