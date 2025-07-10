# SaaS Accelerator Terraform Deployment

This Terraform configuration creates the same Azure infrastructure as the PowerShell script `Deploy.ps1`, but in a declarative way using Infrastructure as Code (IaC).

## Prerequisites

1. **Install Terraform**: Use winget to install Terraform
   ```powershell
   winget install HashiCorp.Terraform
   ```

2. **Azure CLI**: Ensure you have Azure CLI installed and are logged in
   ```powershell
   az login
   ```

3. **Azure PowerShell** (optional): For some administrative tasks
   ```powershell
   Install-Module -Name Az -Force
   ```

## Resources Created

This Terraform configuration creates the following Azure resources:

- **Resource Group**: Container for all resources
- **Virtual Network**: With 4 subnets (default, web, sql, kv)
- **SQL Server**: With Azure AD authentication enabled
- **SQL Database**: Standard tier database
- **Key Vault**: For storing secrets and connection strings
- **App Service Plan**: B1 tier for hosting web applications
- **Two Web Apps**: Admin portal and Customer portal
- **Private Endpoints**: For SQL Server and Key Vault
- **Private DNS Zones**: For private endpoint resolution
- **Network Security**: VNet integration and firewall rules

## Quick Start

1. **Clone or navigate to the deployment directory**:
   ```powershell
   cd C:\Code\Commercial-Marketplace-SaaS-Accelerator\deployment
   ```

2. **Create your variables file**:
   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`** with your specific values:
   ```hcl
   web_app_name_prefix = "mycompany-saas-unique"
   location            = "East US"
   publisher_admin_users = "admin@mycompany.com"
   ```

4. **Initialize Terraform**:
   ```powershell
   terraform init
   ```

5. **Validate the configuration**:
   ```powershell
   terraform validate
   ```

6. **Plan the deployment**:
   ```powershell
   terraform plan
   ```

7. **Apply the configuration**:
   ```powershell
   terraform apply -auto-approve
   ```

## Configuration Variables

### Required Variables

- `web_app_name_prefix`: Prefix for naming resources (max 21 characters)
- `location`: Azure region for deployment
- `publisher_admin_users`: Comma-separated list of admin email addresses

### Optional Variables

- `resource_group_name`: Custom resource group name (defaults to prefix)
- `tenant_id`: Azure AD tenant ID (defaults to current tenant)
- `sql_server_name`: Custom SQL server name (defaults to prefix-sql)
- `sql_database_name`: Custom database name (defaults to prefixAMPSaaSDB)
- `key_vault_name`: Custom Key Vault name (defaults to prefix-kv)
- `ad_application_id`: Existing AD application ID
- `ad_application_secret`: Existing AD application secret
- `ad_application_id_admin`: Existing admin AD application ID
- `ad_mt_application_id_portal`: Existing portal AD application ID
- `is_admin_portal_multi_tenant`: Enable multi-tenant admin portal
- `current_client_ip`: Your IP address for SQL firewall
- `tags`: Resource tags

## Post-Deployment Steps

After successful deployment, you'll need to:

1. **Configure Azure AD App Registrations** (if not provided):
   - Create App Registration for Marketplace API calls
   - Create App Registration for Admin Portal SSO
   - Create App Registration for Landing Page SSO

2. **Update Partner Center**:
   - Add the Landing Page URL: `https://{prefix}-portal.azurewebsites.net/`
   - Add the Webhook URL: `https://{prefix}-portal.azurewebsites.net/api/AzureWebhook`

3. **Deploy Application Code**:
   - Build and deploy the Admin Site
   - Build and deploy the Customer Site
   - Run database migrations

4. **Configure Authentication**:
   - Update AD App Registration redirect URIs
   - Verify ID token issuance is enabled

## Terraform Commands

### Basic Workflow
```powershell
# Initialize
terraform init

# Validate
terraform validate

# Plan
terraform plan

# Apply
terraform apply -auto-approve

# Destroy (when needed)
terraform destroy
```

### Useful Commands
```powershell
# Show current state
terraform show

# List resources
terraform state list

# View outputs
terraform output

# Format code
terraform fmt

# Check for updates
terraform refresh
```

## Differences from PowerShell Script

This Terraform configuration provides the same functionality as the PowerShell script but with these advantages:

1. **Declarative**: Define desired state, not steps
2. **Idempotent**: Safe to run multiple times
3. **State Management**: Tracks resource state
4. **Dependency Management**: Automatic resource ordering
5. **Drift Detection**: Identifies configuration changes
6. **Modular**: Easier to customize and extend

## Notes

- **Key Vault Names**: Must be globally unique and follow naming conventions
- **Web App Names**: Must be globally unique
- **Private Endpoints**: Enable secure communication between services
- **VNet Integration**: Web apps can securely access SQL and Key Vault
- **Authentication**: Uses Azure AD for SQL Server authentication

## Troubleshooting

1. **Name Conflicts**: Ensure resource names are unique
2. **Permissions**: Verify you have Contributor access to the subscription
3. **Quotas**: Check Azure quotas for your subscription
4. **Regions**: Ensure all services are available in your chosen region

## Azure Portal Link

After deployment, visit the [Azure Portal](https://portal.azure.com) to view your resources.

## Support

For issues with the Terraform configuration, check:
- Terraform validation output
- Azure Activity Log
- Resource provider registration
- Network connectivity

For SaaS Accelerator issues, see the [GitHub repository](https://aka.ms/SaaSAccelerator).
