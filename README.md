# Azure App Service Infrastructure with Terraform

This Terraform project creates a secure and scalable infrastructure for hosting multiple Azure App Services with private networking, Azure SQL Database, Key Vault, and Application Gateway.

## Architecture

The infrastructure includes:
- Virtual Network with dedicated subnets for:
  - Application Gateway
  - App Services
  - Private Endpoints
- Private Azure App Services with VNet Integration
- Private Azure SQL Server and Database
- Azure Key Vault with private endpoint
- Application Gateway with WAF for secure access

## Module Structure

- `modules/`
  - `vnet/` - Virtual Network and subnet configuration
  - `app-service/` - App Service Plan and App Services
  - `keyvault/` - Key Vault with private endpoint
  - `sql-server/` - SQL Server and databases
  - `app-gateway/` - Application Gateway with WAF

- `environments/`
  - `dev/` - Development environment configuration
  - `qa/` - QA environment configuration
  - `prod/` - Production environment configuration

## Prerequisites

1. Azure Subscription
2. Azure CLI installed and logged in
3. Terraform 1.0 or later
4. SSL Certificate for Application Gateway

## Usage

1. Initialize Terraform backend:
```bash
terraform init -backend-config="storage_account_name=<storage_account>" \
               -backend-config="container_name=<container>" \
               -backend-config="key=<state_file_name>" \
               -backend-config="access_key=<storage_access_key>"
```

2. Create a `terraform.tfvars` file in the environment directory:
```hcl
location                = "eastus2"
environment            = "dev"
sql_admin_password     = "<your-password>"
ssl_certificate_path   = "path/to/certificate.pfx"
ssl_certificate_password = "<certificate-password>"
app_gateway_domain     = "yourdomain.com"
```

3. Deploy the infrastructure:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

## Adding New App Services

To add new App Services, modify the `app_services` map in the environment configuration:

```hcl
app_services = {
  "app1" = {
    name      = "app-service1-${local.environment}"
    subnet_id = module.vnet.subnet_ids["snet-private-endpoints"]
    app_settings = {
      "WEBSITE_DNS_SERVER"     = "168.63.129.16"
      "WEBSITE_VNET_ROUTE_ALL" = "1"
    }
  }
  "app2" = {
    name      = "app-service2-${local.environment}"
    subnet_id = module.vnet.subnet_ids["snet-private-endpoints"]
    app_settings = {
      "WEBSITE_DNS_SERVER"     = "168.63.129.16"
      "WEBSITE_VNET_ROUTE_ALL" = "1"
    }
  }
}
```

## Security Features

1. Private Endpoints for:
   - App Services
   - Key Vault
   - SQL Server

2. VNet Integration for App Services

3. Web Application Firewall (WAF) on Application Gateway

4. Managed Identities for App Services to access Key Vault

5. Network Security through subnet isolation

## Best Practices

1. Store sensitive information in Key Vault
2. Use different environments for dev, qa, and prod
3. Follow naming conventions for Azure resources
4. Use managed identities for authentication
5. Implement proper network segmentation
6. Enable monitoring and diagnostics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
