# Authentication: Azure CLI identity (az login). No service principal secret in this repo.
# azurerm 5.x: provider registration defaults to none; list the providers Arc needs explicitly.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  resource_providers_to_register = [
    "Microsoft.HybridCompute",
    "Microsoft.GuestConfiguration",
    "Microsoft.HybridConnectivity",
    "Microsoft.Insights",
    "Microsoft.OperationalInsights",
    "Microsoft.PolicyInsights",
  ]
}
