# User-assigned identity so the RBAC grant exists before the container
# boots (a system-assigned identity would race its own role assignment).
resource "azurerm_user_assigned_identity" "worker" {
  name                = "${var.project}-worker-id"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "worker_blob" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

# Private container instance: no public IP, reachable only inside the VNet.
# On start it authenticates with its managed identity and drops a heartbeat
# blob into the data lake through the storage firewall's subnet rule —
# proof that compute, data and network controls are wired together.
resource "azurerm_container_group" "worker" {
  name                = "${var.project}-worker"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  ip_address_type     = "Private"
  subnet_ids          = [var.subnet_id]
  restart_policy      = "OnFailure"
  tags                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.worker.id]
  }

  container {
    name   = "heartbeat"
    image  = "mcr.microsoft.com/azure-cli:2.64.0"
    cpu    = 0.5
    memory = 1.0

    ports {
      port     = 80
      protocol = "TCP"
    }

    commands = [
      "/bin/sh", "-c",
      <<-EOT
        set -e
        for i in $(seq 1 12); do
          az login --identity --username ${azurerm_user_assigned_identity.worker.client_id} && break
          echo "waiting for managed identity..." && sleep 10
        done
        echo "heartbeat from ${var.project}-worker at $(date -u)" > /tmp/heartbeat.txt
        az storage blob upload \
          --auth-mode login \
          --account-name ${var.storage_account} \
          --container-name ${var.data_container} \
          --name "heartbeats/heartbeat-$(date -u +%Y%m%dT%H%M%SZ).txt" \
          --file /tmp/heartbeat.txt \
          --overwrite
        echo "heartbeat uploaded"
      EOT
    ]
  }

  depends_on = [azurerm_role_assignment.worker_blob]
}
