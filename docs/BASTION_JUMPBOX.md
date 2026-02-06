# Azure Bastion & Jumpbox Configuration

This infrastructure now supports optional deployment of Azure Bastion and a Jumpbox VM for secure management access to your cloud resources without exposing them to the public internet.

## Components

### Azure Bastion
- **Module**: `components/compute/bastion.bicep`
- **Description**: Azure Bastion provides secure RDP/SSH access to virtual machines without requiring public IP addresses
- **Subnet**: `AzureBastionSubnet` (10.0.10.0/27)
- **SKU Options**: 
  - Basic: Single-user access
  - Standard: Multi-user with advanced features (tunneling, IP Connect)

### Jumpbox VM
- **Module**: `components/compute/jumpbox.bicep`
- **Description**: Windows Server VM for management and administration tasks
- **OS**: Windows Server 2022 Datacenter (Azure Edition)
- **Features**:
  - No public IP (accessible only via Bastion)
  - Premium SSD OS disk
  - TrustedLaunch security
  - Azure Monitor agent for diagnostics
  - Pre-installed tools: Azure CLI, AzCopy, Git, VS Code, Azure PowerShell
  - Secure Boot & vTPM enabled
- **Subnet**: `snet-jumpbox` (10.0.11.0/27)

## Deployment

### Enable in Parameters

Edit `infra/main.bicepparam`:

```bicep
// Bastion and Jumpbox Configuration (Optional)
param deployBastion = true        // Set to true to enable
param deployJumpbox = true        // Set to true to enable
param jumpboxAdminUsername = 'azureadmin'
param jumpboxAdminPassword = 'YourSecurePassword123!'  // Use a strong password
```

### Using Azure Developer CLI

```bash
# Deploy with Bastion and Jumpbox
azd provision

# Or use --parameter-override for non-interactive deployment
azd provision --parameter-override "deployBastion=true deployJumpbox=true jumpboxAdminPassword=YourSecurePassword123!"
```

## Access the Jumpbox

### Via Azure Portal
1. Navigate to the Jumpbox VM resource
2. Click "Connect" → "Bastion"
3. Enter credentials: username `azureadmin`, your chosen password
4. Click "Connect"

### Via Azure CLI
```bash
# Get jumpbox details
az vm list --resource-group rg-dev-dbxaml-shared \
  --query "[?contains(name, 'jumpbox')]" \
  --output table

# RDP via Bastion
az network bastion rdp --name bastion-dev-dbxaml \
  --resource-group rg-dev-dbxaml-shared \
  --target-resource-id <jumpbox-vm-id>
```

## Network Security

### Bastion Subnet (10.0.10.0/27)
- No NSG rules required (Azure Bastion is fully managed)
- Automatic Azure service communication

### Jumpbox Subnet (10.0.11.0/27)
- Inbound: Only from Bastion subnet (ports 3389/22 for RDP/SSH)
- Outbound: Allowed to Azure services (Storage, Key Vault, etc.)
- Public internet: Blocked by default

## Use Cases

1. **Management VM**: Run administrative scripts and PowerShell
2. **Testing**: Test connectivity and firewall rules
3. **Debugging**: Access to Databricks cluster configuration
4. **Data Transfer**: Use AzCopy to transfer data securely
5. **Development**: Lightweight development environment

## Cost Considerations

- **Bastion Basic**: ~$10-15/month
- **Bastion Standard**: ~$30-40/month (with advanced features)
- **Jumpbox VM**: ~$50-100/month (Standard_D2s_v3)

> **Tip**: Disable Bastion/Jumpbox in non-production environments to reduce costs:
> ```bicep
> param deployBastion = false
> param deployJumpbox = false
> ```

## Post-Deployment

The Jumpbox is pre-configured with:

1. **Azure CLI** - Cloud management commands
2. **AzCopy** - High-performance data transfer
3. **Git** - Version control
4. **Azure PowerShell** - PowerShell modules for Azure
5. **Visual Studio Code** - Code editor
6. **Azure Monitor Agent** - Diagnostics and monitoring

Install additional tools as needed:

```powershell
# Example: Install Databricks CLI
pip install databricks-cli

# Example: Install Terraform
choco install terraform

# Example: Install Azure Storage Explorer
choco install azure-storage-explorer
```

## Troubleshooting

### Bastion Connection Issues
1. Check Network Security Group rules
2. Verify Bastion has a valid public IP
3. Ensure VM is in the correct subnet
4. Check regional availability

### Jumpbox Connectivity
1. Verify jumpbox NSG allows Bastion subnet
2. Check Bastion is deployed and in "Succeeded" state
3. Verify jumpbox VM is running
4. Check admin credentials are correct

## Disabling Bastion & Jumpbox

To remove these resources:

```bicep
param deployBastion = false
param deployJumpbox = false
```

Then redeploy:
```bash
azd provision
```

## Security Best Practices

- ✅ Use strong passwords (minimum 12 characters, mixed case, numbers, symbols)
- ✅ Enable Azure Monitor logging
- ✅ Use Bastion for all VM access (never expose RDP publicly)
- ✅ Regularly patch the Jumpbox OS
- ✅ Delete Jumpbox when not in use in dev/test environments
- ✅ Use Azure AD authentication if available
- ❌ Don't expose Jumpbox public IPs
- ❌ Don't disable Bastion NSG rules
- ❌ Don't store credentials on Jumpbox VM
