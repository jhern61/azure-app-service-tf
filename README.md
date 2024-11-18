# Azure App Service Infrastructure with Terraform

This Terraform project creates a secure and scalable infrastructure for hosting multiple Azure App Services and AKS clusters with private networking, Azure SQL Database, Key Vault, and Application Gateway.

## Architecture

The infrastructure includes:
- Virtual Network with dedicated subnets for:
  - Application Gateway
  - App Services
  - Private Endpoints
  - AKS Clusters
  - Virtual Machines
- Private Azure App Services with VNet Integration
- Multiple AKS Clusters with:
  - System and User Node Pools
  - Auto-scaling capabilities
  - Azure CNI networking
  - Azure Monitor integration
- Private Azure SQL Server and Database
- Azure Key Vault with private endpoint
- Application Gateway with WAF for secure access
- Virtual Machines with availability sets

## Module Structure

- `modules/`
  - `vnet/` - Virtual Network and subnet configuration
  - `app-service/` - App Service Plan and App Services
  - `keyvault/` - Key Vault with private endpoint
  - `sql-server/` - SQL Server and databases
  - `app-gateway/` - Application Gateway with WAF
  - `aks/` - Azure Kubernetes Service clusters and node pools
  - `vm/` - Virtual Machines and availability sets

- `environments/`
  - `dev/` - Development environment configuration
  - `qa/` - QA environment configuration
  - `prod/` - Production environment configuration

## Prerequisites

1. Azure Subscription
2. Azure CLI installed and logged in
3. Terraform 1.0 or later
4. SSL Certificate for Application Gateway
5. kubectl for AKS cluster management

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
vm_admin_username      = "<vm-username>"
vm_admin_password      = "<vm-password>"
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
}
```

## Adding New AKS Clusters

To add new AKS clusters, modify the `clusters` map in the environment configuration:

```hcl
clusters = {
  "primary" = {
    name               = "aks-${local.environment}-primary"
    kubernetes_version = "1.26.3"
    vnet_subnet_id    = module.vnet.subnet_ids["snet-aks"]
    
    system_node_pool = {
      name                = "system"
      vm_size            = "Standard_D4s_v3"
      enable_auto_scaling = true
      node_count         = 1
      min_count          = 1
      max_count          = 3
    }

    user_node_pools = {
      "general" = {
        vm_size            = "Standard_D4s_v3"
        enable_auto_scaling = true
        node_count         = 2
        min_count          = 2
        max_count          = 5
        node_labels = {
          "workload-type" = "general"
        }
      }
    }
  }
}
```

## Security Features

1. Private Endpoints for:
   - App Services
   - Key Vault
   - SQL Server

2. Network Security:
   - VNet Integration for App Services
   - Azure CNI for AKS clusters
   - Private subnets for node pools
   - Network policies enabled

3. Access Control:
   - Web Application Firewall (WAF) on Application Gateway
   - Managed Identities for service authentication
   - Azure AD integration for AKS
   - RBAC enabled for Kubernetes

4. Monitoring and Logging:
   - Azure Monitor integration
   - Log Analytics workspaces per cluster
   - Application Insights integration

## Disaster Recovery

The infrastructure supports geo-redundant deployments with:
1. Secondary region deployment
2. Cross-region load balancing
3. Database replication
4. Multiple AKS clusters for high availability

## Network Configuration

The infrastructure uses a hub-spoke network topology with:
1. Dedicated subnets for each service
2. Network security groups
3. Private endpoints for PaaS services
4. NAT Gateway for outbound traffic

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
