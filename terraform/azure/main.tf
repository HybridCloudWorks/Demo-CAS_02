locals {
  common_tags = {
    Environment    = "Demo"
    Session        = "AzureArcHybrid"
    Owner          = var.owner
    ManagedBy      = "Terraform"
    CostCenter     = var.cost_center
    ExpirationDate = var.expiration_date
  }

  # Built-in policy definition IDs (verified on Microsoft Learn, Oct 2026)
  policy_linux_baseline_audit = "/providers/Microsoft.Authorization/policyDefinitions/fc9b3da7-8347-4380-8e70-0a0361d8dedd" # Linux machines should meet requirements for the Azure compute security baseline
  policy_arc_linux_ama_dine   = "/providers/Microsoft.Authorization/policyDefinitions/845857af-0333-4c5d-bbbc-6076697da122" # Configure Linux Arc-enabled machines to run Azure Monitor Agent
  policy_arc_linux_dcr_dine   = "/providers/Microsoft.Authorization/policyDefinitions/d5c37ce1-5f52-4523-b949-f19bf945b73a" # Configure Linux Arc Machines to be associated with a DCR or DCE
  policy_inherit_tag_missing  = "/providers/Microsoft.Authorization/policyDefinitions/ea3f2387-9b95-492a-a190-fcdc54f7b070" # Inherit a tag from the resource group if missing
}

resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------- health signal plane
resource "azurerm_log_analytics_workspace" "demo" {
  name                = var.workspace_name
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = local.common_tags
}

# Collect syslog "user" facility where the demo heartbeat writes its health line.
# Argument names for azurerm 5.x: verification required against current official documentation.
resource "azurerm_monitor_data_collection_rule" "arc_linux" {
  name                = "dcr-arc-hybrid-demo-linux"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  kind                = "Linux"
  tags                = local.common_tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.demo.id
      name                  = "law-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["law-destination"]
  }

  data_sources {
    syslog {
      name           = "arc-demo-syslog"
      facility_names = ["user", "daemon"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      streams        = ["Microsoft-Syslog"]
    }
  }
}

# ---------------------------------------------------------------- governance
# Audit only: no change to machines. Machine Configuration on Arc = billable per server.
resource "azurerm_resource_group_policy_assignment" "linux_baseline" {
  count                = var.deploy_policy ? 1 : 0
  name                 = "arc-demo-linux-baseline-audit"
  display_name         = "Arc demo: Linux compute security baseline (audit)"
  resource_group_id    = azurerm_resource_group.demo.id
  policy_definition_id = local.policy_linux_baseline_audit
}

# DeployIfNotExists: installs AMA on Arc Linux machines in the RG.
resource "azurerm_resource_group_policy_assignment" "ama_dine" {
  count                = var.deploy_policy ? 1 : 0
  name                 = "arc-demo-linux-ama"
  display_name         = "Arc demo: deploy Azure Monitor Agent to Linux Arc machines"
  resource_group_id    = azurerm_resource_group.demo.id
  policy_definition_id = local.policy_arc_linux_ama_dine
  location             = azurerm_resource_group.demo.location
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_resource_group_policy_assignment" "dcr_dine" {
  count                = var.deploy_policy ? 1 : 0
  name                 = "arc-demo-linux-dcr"
  display_name         = "Arc demo: associate Linux Arc machines with the demo DCR"
  resource_group_id    = azurerm_resource_group.demo.id
  policy_definition_id = local.policy_arc_linux_dcr_dine
  location             = azurerm_resource_group.demo.location
  identity {
    type = "SystemAssigned"
  }
  parameters = jsonencode({
    dcrResourceId = { value = azurerm_monitor_data_collection_rule.arc_linux.id }
    resourceType  = { value = "Microsoft.Insights/dataCollectionRules" }
  })
}

# Inherit Session tag from RG only if missing; never overwrites CloudOrigin set by azcmagent --tags.
resource "azurerm_resource_group_policy_assignment" "inherit_session_tag" {
  count                = var.deploy_policy ? 1 : 0
  name                 = "arc-demo-inherit-session-tag"
  display_name         = "Arc demo: inherit Session tag if missing"
  resource_group_id    = azurerm_resource_group.demo.id
  policy_definition_id = local.policy_inherit_tag_missing
  location             = azurerm_resource_group.demo.location
  identity {
    type = "SystemAssigned"
  }
  parameters = jsonencode({
    tagName = { value = "Session" }
  })
}

# DINE/Modify assignments need rights on the RG to remediate.
# Lab-only shortcut. Not recommended for production: Contributor on the demo RG for the policy identities.
# Production alternative: Log Analytics Contributor + Azure Connected Machine Resource Administrator + Monitoring Contributor, scoped to the RG.
resource "azurerm_role_assignment" "ama_dine_rg" {
  count                = var.deploy_policy ? 1 : 0
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.ama_dine[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "dcr_dine_rg" {
  count                = var.deploy_policy ? 1 : 0
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.dcr_dine[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "tag_modify_rg" {
  count                = var.deploy_policy ? 1 : 0
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Tag Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.inherit_session_tag[0].identity[0].principal_id
}

# ---------------------------------------------------------------- optional AI layer
# Verification required against current official documentation: resource name/kind for Microsoft Foundry in azurerm 5.x.
resource "azurerm_cognitive_account" "foundry" {
  count                 = var.deploy_foundry ? 1 : 0
  name                  = var.foundry_name
  location              = azurerm_resource_group.demo.location
  resource_group_name   = azurerm_resource_group.demo.name
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = var.foundry_name
  local_auth_enabled    = false # Entra ID only; no API keys
  tags                  = local.common_tags
}
