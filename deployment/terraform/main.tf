# Initializing Terraform and required providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.35.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }
  }
}

# Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Azure AD Provider
provider "azuread" {}

# Data sources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Use the object_id to fetch user details
data "azuread_user" "current_user" {
  object_id = data.azurerm_client_config.current.object_id
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  address_space       = ["10.4.0.0/20"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.4.0.0/24"]
}

resource "azurerm_subnet" "web" {
  name                 = "web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.4.1.0/24"]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.KeyVault"]
  
  delegation {
    name = "Microsoft.Web.serverFarms"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "sql" {
  name                 = "sql"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.4.2.0/24"]
}

resource "azurerm_subnet" "kv" {
  name                 = "kv"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.4.3.0/24"]
}

# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  minimum_tls_version          = "1.2"
  public_network_access_enabled = true
  tags                         = var.tags

  azuread_administrator {
    login_username              = data.azuread_user.current_user.user_principal_name
    object_id                   = data.azuread_user.current_user.object_id
    tenant_id                   = var.tenant_id
    azuread_authentication_only = true
  }
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name           = local.sql_database_name
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 250
  sku_name       = "S0"
  zone_redundant = false
  tags           = var.tags
}

# SQL Server Firewall Rules
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureIP"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_current_ip" {
  count            = var.current_client_ip != "" ? 1 : 0
  name             = "AllowCurrentIP"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = var.current_client_ip
  end_ip_address   = var.current_client_ip
}

# SQL Server Virtual Network Rule
resource "azurerm_mssql_virtual_network_rule" "web_subnet" {
  name      = "${var.web_app_name_prefix}-vnet"
  server_id = azurerm_mssql_server.main.id
  subnet_id = azurerm_subnet.web.id
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  enable_rbac_authorization = false
  
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [
      azurerm_subnet.web.id
    ]
  }
}

# Key Vault Access Policy for Current User
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Purge"
  ]
}

# Key Vault Secrets
resource "azurerm_key_vault_secret" "ad_application_secret" {
  count        = var.ad_application_secret != "" ? 1 : 0
  name         = "ADApplicationSecret"
  value        = var.ad_application_secret
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}

resource "azurerm_key_vault_secret" "default_connection" {
  name         = "DefaultConnection"
  value        = local.sql_connection_string
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = local.app_service_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Windows"
  sku_name            = "B1"
  tags                = var.tags
}

# Admin Web App
resource "azurerm_windows_web_app" "admin" {
  name                = local.admin_webapp_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.main.id
  tags                = var.tags

  site_config {
    always_on = true
    
    application_stack {
      dotnet_version = "v8.0"
    }
  }

  app_settings = {
    "KnownUsers"                                       = var.publisher_admin_users
    "SaaSApiConfiguration_CodeHash"                    = "terraform-deployment"
    "SaaSApiConfiguration__AdAuthenticationEndPoint"   = "https://login.microsoftonline.com"
    "SaaSApiConfiguration__ClientId"                   = var.ad_application_id
    "SaaSApiConfiguration__ClientSecret"               = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=ADApplicationSecret)"
    "SaaSApiConfiguration__FulFillmentAPIBaseURL"      = "https://marketplaceapi.microsoft.com/api"
    "SaaSApiConfiguration__FulFillmentAPIVersion"      = "2018-08-31"
    "SaaSApiConfiguration__GrantType"                  = "client_credentials"
    "SaaSApiConfiguration__MTClientId"                 = var.ad_application_id_admin
    "SaaSApiConfiguration__IsAdminPortalMultiTenant"   = var.is_admin_portal_multi_tenant
    "SaaSApiConfiguration__Resource"                   = "20e940b3-4c77-4b0b-9a53-9e16a1b010a7"
    "SaaSApiConfiguration__TenantId"                   = var.tenant_id
    "SaaSApiConfiguration__SignedOutRedirectUri"      = "https://${local.admin_webapp_name}.azurewebsites.net/Home/Index/"
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=DefaultConnection)"
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_key_vault.main]
}

# Customer Portal Web App
resource "azurerm_windows_web_app" "portal" {
  name                = local.portal_webapp_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.main.id
  tags                = var.tags

  site_config {
    always_on = true
    
    application_stack {
      dotnet_version = "v8.0"
    }
  }

  app_settings = {
    "SaaSApiConfiguration_CodeHash"                    = "terraform-deployment"
    "SaaSApiConfiguration__AdAuthenticationEndPoint"   = "https://login.microsoftonline.com"
    "SaaSApiConfiguration__ClientId"                   = var.ad_application_id
    "SaaSApiConfiguration__ClientSecret"               = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=ADApplicationSecret)"
    "SaaSApiConfiguration__FulFillmentAPIBaseURL"      = "https://marketplaceapi.microsoft.com/api"
    "SaaSApiConfiguration__FulFillmentAPIVersion"      = "2018-08-31"
    "SaaSApiConfiguration__GrantType"                  = "client_credentials"
    "SaaSApiConfiguration__MTClientId"                 = var.ad_mt_application_id_portal
    "SaaSApiConfiguration__Resource"                   = "20e940b3-4c77-4b0b-9a53-9e16a1b010a7"
    "SaaSApiConfiguration__TenantId"                   = var.tenant_id
    "SaaSApiConfiguration__SignedOutRedirectUri"      = "https://${local.portal_webapp_name}.azurewebsites.net/Home/Index/"
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=DefaultConnection)"
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_key_vault.main]
}

# Key Vault Access Policy for Admin Web App
resource "azurerm_key_vault_access_policy" "admin_webapp" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_web_app.admin.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
  
  key_permissions = [
    "Get",
    "List"
  ]
}

# Key Vault Access Policy for Portal Web App
resource "azurerm_key_vault_access_policy" "portal_webapp" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_web_app.portal.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
  
  key_permissions = [
    "Get",
    "List"
  ]
}

# VNet Integration for Admin Web App
resource "azurerm_app_service_virtual_network_swift_connection" "admin" {
  app_service_id = azurerm_windows_web_app.admin.id
  subnet_id      = azurerm_subnet.web.id
}

# VNet Integration for Portal Web App
resource "azurerm_app_service_virtual_network_swift_connection" "portal" {
  app_service_id = azurerm_windows_web_app.portal.id
  subnet_id      = azurerm_subnet.web.id
}

# Private DNS Zones
resource "azurerm_private_dns_zone" "sql" {
  name                = local.private_sql_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "kv" {
  name                = local.private_kv_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Private DNS Zone Virtual Network Links
resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = local.private_sql_link_name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                  = local.private_kv_link_name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags                  = var.tags
}

# Private Endpoints
resource "azurerm_private_endpoint" "sql" {
  name                = local.private_sql_endpoint_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.sql.id
  tags                = var.tags

  private_service_connection {
    name                           = "sqlConnection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "sql-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}

resource "azurerm_private_endpoint" "kv" {
  name                = local.private_kv_endpoint_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.kv.id
  tags                = var.tags

  private_service_connection {
    name                           = "kvConnection"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}
