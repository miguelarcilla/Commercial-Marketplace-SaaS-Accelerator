variable "subscription_id" {
  description = "The Azure Subscription ID against which the resources will be deployed"
  default     = "null"
}

variable "web_app_name_prefix" {
  description = "Prefix used for creating web applications"
  type        = string
  validation {
    condition     = length(var.web_app_name_prefix) <= 21
    error_message = "Web name prefix must be less than 21 characters."
  }
}

variable "location" {
  description = "Location of the resource group"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy the resources"
  type        = string
  default     = ""
}

variable "publisher_admin_users" {
  description = "Provide a list of email addresses (as comma-separated-values) that should be granted access to the Publisher Portal"
  type        = string
}

variable "tenant_id" {
  description = "The value should match the value provided for Active Directory TenantID in the Technical Configuration of the Transactable Offer in Partner Center"
  type        = string
  default     = ""
}

variable "ad_application_id" {
  description = "The value should match the value provided for Active Directory Application ID in the Technical Configuration of the Transactable Offer in Partner Center"
  type        = string
  default     = ""
}

variable "ad_application_secret" {
  description = "Secret key of the AD Application"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ad_application_id_admin" {
  description = "Multi-Tenant Active Directory Application ID for Admin Portal"
  type        = string
  default     = ""
}

variable "ad_mt_application_id_portal" {
  description = "Multi-Tenant Active Directory Application ID for the Landing Portal"
  type        = string
  default     = ""
}

variable "is_admin_portal_multi_tenant" {
  description = "If set to true, the Admin Portal will be configured as a multi-tenant application"
  type        = bool
  default     = false
}

variable "sql_database_name" {
  description = "Name of the database"
  type        = string
  default     = ""
}

variable "sql_server_name" {
  description = "Name of the database server (without database.windows.net)"
  type        = string
  default     = ""
}

variable "key_vault_name" {
  description = "Name of KeyVault"
  type        = string
  default     = ""
  validation {
    condition     = var.key_vault_name == "" || can(regex("^[a-zA-Z][a-z0-9-]+$", var.key_vault_name))
    error_message = "KeyVault name only allows alphanumeric and hyphens, but cannot start with a number or special character."
  }
}

variable "logo_url_png" {
  description = "URL for Publisher .png logo"
  type        = string
  default     = ""
}

variable "logo_url_ico" {
  description = "URL for Publisher .ico logo"
  type        = string
  default     = ""
}

variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  default     = ""
}

variable "sql_admin_object_id" {
  description = "SQL Server administrator object ID"
  type        = string
  default     = ""
}

variable "current_client_ip" {
  description = "Current client IP address for SQL firewall rule"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

# Local variables for computed values
locals {
  resource_group_name    = var.resource_group_name != "" ? var.resource_group_name : var.web_app_name_prefix
  sql_server_name        = var.sql_server_name != "" ? var.sql_server_name : "${var.web_app_name_prefix}-sql"
  sql_database_name      = var.sql_database_name != "" ? var.sql_database_name : "${var.web_app_name_prefix}AMPSaaSDB"
  key_vault_name         = var.key_vault_name != "" ? var.key_vault_name : "${var.web_app_name_prefix}-kv"
  
  # Resource names
  app_service_plan_name     = "${var.web_app_name_prefix}-asp"
  admin_webapp_name         = "${var.web_app_name_prefix}-admin"
  portal_webapp_name        = "${var.web_app_name_prefix}-portal"
  vnet_name                 = "${var.web_app_name_prefix}-vnet"
  private_sql_endpoint_name = "${var.web_app_name_prefix}-db-pe"
  private_kv_endpoint_name  = "${var.web_app_name_prefix}-kv-pe"
  private_sql_link_name     = "${var.web_app_name_prefix}-db-link"
  private_kv_link_name      = "${var.web_app_name_prefix}-kv-link"
  
  # DNS zones
  private_sql_dns_zone_name = "privatelink.database.windows.net"
  private_kv_dns_zone_name  = "privatelink.vaultcore.azure.net"
  
  # Connection strings
  server_uri_private = "${local.sql_server_name}.privatelink.database.windows.net"
  sql_connection_string = "Server=tcp:${local.server_uri_private};Database=${local.sql_database_name};TrustServerCertificate=True;Authentication=Active Directory Managed Identity;"
  
  # Application settings
  saas_api_configuration = {
    AdAuthenticationEndPoint       = "https://login.microsoftonline.com"
    FulFillmentAPIBaseURL         = "https://marketplaceapi.microsoft.com/api"
    FulFillmentAPIVersion         = "2018-08-31"
    GrantType                     = "client_credentials"
    Resource                      = "20e940b3-4c77-4b0b-9a53-9e16a1b010a7"
    TenantId                      = var.tenant_id
    ClientId                      = var.ad_application_id
    MTClientId                    = var.ad_application_id_admin
    IsAdminPortalMultiTenant      = var.is_admin_portal_multi_tenant
    SignedOutRedirectUri          = "https://${local.admin_webapp_name}.azurewebsites.net/Home/Index/"
  }
  
  portal_saas_api_configuration = {
    AdAuthenticationEndPoint       = "https://login.microsoftonline.com"
    FulFillmentAPIBaseURL         = "https://marketplaceapi.microsoft.com/api"
    FulFillmentAPIVersion         = "2018-08-31"
    GrantType                     = "client_credentials"
    Resource                      = "20e940b3-4c77-4b0b-9a53-9e16a1b010a7"
    TenantId                      = var.tenant_id
    ClientId                      = var.ad_application_id
    MTClientId                    = var.ad_mt_application_id_portal
    SignedOutRedirectUri          = "https://${local.portal_webapp_name}.azurewebsites.net/Home/Index/"
  }
}
