terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state in Azure Storage. All values are injected by CI via
  # -backend-config flags so nothing environment-specific lives in code.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  # Data-plane operations (blob container management) authenticate with
  # Entra ID instead of storage account keys — keys are disabled entirely.
  storage_use_azuread = true
}
