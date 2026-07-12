# ADLS Gen2 data lake. Storage account keys are disabled: every access —
# including Terraform's own container management — goes through Entra ID.
resource "azurerm_storage_account" "data" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  tags = merge(var.tags, { role = "data" })
}

# Referencing the account by id makes the provider manage this container
# through the management plane, so the storage firewall can't lock
# Terraform out of its own resources.
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

# Network-level lockdown: deny everything except the compute subnet
# (via service endpoint) and trusted Azure services. The CI pipeline
# temporarily allowlists the runner's IP so Terraform can manage the
# data plane; ip_rules are ignored here so that never causes drift.
resource "azurerm_storage_account_network_rules" "data" {
  storage_account_id = azurerm_storage_account.data.id

  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  virtual_network_subnet_ids = var.allowed_subnet_ids

  lifecycle {
    ignore_changes = [ip_rules]
  }

  # Create the container while the account is still open on first apply.
  depends_on = [azurerm_storage_container.data]
}
