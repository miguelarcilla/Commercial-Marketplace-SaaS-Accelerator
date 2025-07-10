output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "location" {
  description = "Location of the resources"
  value       = azurerm_resource_group.rg.location
}

output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = azurerm_mssql_server.main.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.main.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "admin_webapp_name" {
  description = "Name of the Admin Web App"
  value       = azurerm_windows_web_app.admin.name
}

output "admin_webapp_url" {
  description = "URL of the Admin Web App"
  value       = "https://${azurerm_windows_web_app.admin.default_hostname}"
}

output "portal_webapp_name" {
  description = "Name of the Portal Web App"
  value       = azurerm_windows_web_app.portal.name
}

output "portal_webapp_url" {
  description = "URL of the Portal Web App"
  value       = "https://${azurerm_windows_web_app.portal.default_hostname}"
}

output "app_service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.main.name
}

output "virtual_network_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "private_sql_endpoint_name" {
  description = "Name of the SQL Private Endpoint"
  value       = azurerm_private_endpoint.sql.name
}

output "private_kv_endpoint_name" {
  description = "Name of the Key Vault Private Endpoint"
  value       = azurerm_private_endpoint.kv.name
}

output "deployment_urls" {
  description = "Important URLs for post-deployment configuration"
  value = {
    admin_portal_url     = "https://${azurerm_windows_web_app.admin.default_hostname}"
    customer_portal_url  = "https://${azurerm_windows_web_app.portal.default_hostname}"
    landing_page_url     = "https://${azurerm_windows_web_app.portal.default_hostname}/"
    webhook_url          = "https://${azurerm_windows_web_app.portal.default_hostname}/api/AzureWebhook"
  }
}

output "configuration_notes" {
  description = "Important configuration notes"
  value = {
    message = "After deployment, you will need to:"
    tasks = [
      "1. Configure Azure AD App Registrations with the provided URLs",
      "2. Add the Landing Page URL to Partner Center SaaS Technical Configuration",
      "3. Add the Webhook URL to Partner Center Connection Webhook section",
      "4. Deploy your application code to the Web Apps",
      "5. Run database migrations and initial setup"
    ]
  }
}
