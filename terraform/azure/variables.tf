variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "location" {
  description = "Azure region for Arc metadata, workspace and DCR (workloads stay where they run)."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Dedicated demo resource group."
  type        = string
  default     = "rg-arc-hybrid-demo"
  validation {
    condition     = can(regex("^[-\\w\\._\\(\\)]{1,90}$", var.resource_group_name))
    error_message = "Invalid resource group name."
  }
}

variable "workspace_name" {
  description = "Log Analytics workspace name."
  type        = string
  default     = "law-arc-hybrid-demo"
}

variable "retention_days" {
  description = "Workspace retention. 30 is the minimum paid tier; keep short for a demo."
  type        = number
  default     = 30
  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 90
    error_message = "retention_days must be between 30 and 90 for the demo."
  }
}

variable "deploy_policy" {
  description = "Assign the Arc governance policies (audit baseline, AMA DINE, tag inheritance). Machine Configuration on Arc servers is billable."
  type        = bool
  default     = true
}

variable "deploy_foundry" {
  description = "Optional: create Microsoft Foundry (AI Services) resource for the explanation layer. Verification required against current official documentation for azurerm 5.x resource names."
  type        = bool
  default     = false
}

variable "foundry_name" {
  description = "Name for the optional Foundry / AI Services account."
  type        = string
  default     = "ais-arc-hybrid-demo"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "<OWNER>"
}

variable "cost_center" {
  description = "CostCenter tag."
  type        = string
  default     = "<COST_CENTER>"
}

variable "expiration_date" {
  description = "ExpirationDate tag (YYYY-MM-DD)."
  type        = string
  default     = "<EXPIRATION_DATE>"
}
