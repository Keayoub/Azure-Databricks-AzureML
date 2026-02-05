# Azure Container Apps (ACA) and AKS Optional Deployment Guide

## Overview

This infrastructure now supports **optional deployment** of Azure Container Apps (ACA) and Azure Kubernetes Service (AKS) alongside Azure Databricks, Azure ML, and AI Foundry. The implementation follows Microsoft's Landing Zone Accelerator patterns for both services.

## Architecture Components

### Azure Container Apps (ACA)
- **Internal Environment**: Private network deployment with no public ingress
- **VNet Integration**: Dedicated `/23` infrastructure subnet with delegation
- **Private DNS**: Automatic DNS zone creation and configuration
- **Monitoring**: Integrated with Log Analytics and Application Insights
- **Workload Profiles**: Consumption-based scaling
- **Dapr Support**: Built-in Dapr integration with AI instrumentation

### Azure Kubernetes Service (AKS)
- **Private Cluster**: API server only accessible via private network
- **Dual Node Pools**:
  - **System Pool**: For Kubernetes system components
  - **User Pool**: For inference workloads (tainted for specific workloads)
- **Network Plugin**: Azure CNI with Cilium dataplane
- **Security**:
  - Workload Identity enabled
  - Azure Policy addon
  - Defender for Containers
  - Image Cleaner enabled
- **Monitoring**: Dedicated Log Analytics workspace

## Deployment Options

### Parameter Configuration

Edit `infra/main.bicepparam` to enable/disable components:

```bicep
// Feature flags
param enableUnityCatalog = true
param deployAzureML = true
param deployAIFoundry = true
param deployAKS = false  // Set to true to deploy AKS
param deployACA = false  // Set to true to deploy ACA
param aksNodeCount = 3
```

### Deployment Scenarios

#### Scenario 1: Databricks + Azure ML Only (Default)
```bicep
param deployAzureML = true
param deployAIFoundry = true
param deployAKS = false
param deployACA = false
```

#### Scenario 2: Full AI Platform with Container Orchestration
```bicep
param deployAzureML = true
param deployAIFoundry = true
param deployAKS = true
param deployACA = true
```

#### Scenario 3: Databricks + ACA for Microservices
```bicep
param deployAzureML = false
param deployAIFoundry = false
param deployAKS = false
param deployACA = true
```

## Network Architecture

### Subnet Allocation

| Subnet | CIDR | Purpose |
|--------|------|---------|
| Databricks Public | 10.0.1.0/24 | Databricks control plane communication |
| Databricks Private | 10.0.2.0/24 | Databricks worker nodes |
| Azure ML Compute | 10.0.3.0/24 | Azure ML compute instances |
| AKS | 10.0.4.0/23 | Kubernetes nodes and pods |
| Private Endpoints | 10.0.6.0/24 | Private endpoints for Azure services |
| ACA Infrastructure | 10.0.7.0/23 | Container Apps environment infrastructure |

### Network Security Groups

#### ACA Infrastructure NSG
- Allows HTTPS (443) inbound from anywhere (for Application Gateway integration)
- Delegates to Microsoft.App/environments

#### AKS NSG
- Configured for private cluster requirements
- Service endpoints for Storage and Container Registry

## Resource Organization

All optional components deploy to the **Shared Resource Group** alongside:
- Virtual Network
- Container Registry
- Key Vault
- Storage Account
- Monitoring resources

### Resource Naming Convention

| Resource Type | Naming Pattern | Example |
|--------------|----------------|---------|
| Container Apps Environment | `cae-{project}-{env}` | `cae-dbxaml-dev` |
| AKS Cluster | `aks-{project}-{env}` | `aks-dbxaml-dev` |
| Log Analytics (AKS) | `log-{project}-{env}` | `log-dbxaml-dev` |

## Container Apps Environment Details

### Configuration
- **Type**: Internal (private) environment
- **Zone Redundancy**: Disabled (enable for production)
- **Workload Profiles**: Consumption only (can add Dedicated profiles)
- **Infrastructure RG**: Auto-generated as `ME_{rg-name}_{environment-name}`

### Integration Points
1. **VNet**: Dedicated subnet with /23 minimum
2. **Monitoring**: Log Analytics workspace from monitoring module
3. **Application Insights**: Optional Dapr instrumentation
4. **DNS**: Private DNS zone for `*.{environment}.{region}.azurecontainerapps.io`

## AKS Cluster Details

### Node Pools

#### System Node Pool
- **VM Size**: Standard_DS3_v2
- **OS**: Azure Linux
- **Count**: 1-10 (auto-scaling)
- **Purpose**: Kubernetes system components

#### User Node Pool
- **VM Size**: Standard_D4s_v3
- **OS**: Azure Linux
- **Count**: 0-20 (auto-scaling, can scale to zero)
- **Purpose**: Inference workloads
- **Taints**: `workload=inference:NoSchedule`

### Security Features
1. **Private Cluster**: API server not publicly accessible
2. **Workload Identity**: For pod-to-Azure resource authentication
3. **Azure Policy**: Enforce Kubernetes policies
4. **Defender for Containers**: Security monitoring
5. **Image Cleaner**: Automatic cleanup of unused images (24h interval)

### Storage
- **Blob CSI Driver**: Enabled
- **Disk CSI Driver**: Enabled
- **File CSI Driver**: Enabled
- **Snapshot Controller**: Enabled

## Deployment Commands

### Deploy Full Infrastructure with ACA and AKS

```powershell
# Update parameters
code infra/main.bicepparam

# Preview deployment
azd provision --preview

# Deploy
azd provision
```

### Deploy Only ACA

```powershell
# Set in bicepparam
param deployACA = true
param deployAKS = false

azd provision
```

### Deploy Only AKS

```powershell
# Set in bicepparam
param deployACA = false
param deployAKS = true

azd provision
```

## Post-Deployment Configuration

### For Azure Container Apps

1. **Deploy Your First Container App**:
```bash
# Example using Azure CLI (adjust RG: rg-{env}-{project}-shared)
az containerapp create \
  --name my-app \
  --resource-group rg-dev-dbxaml-shared \
  --environment cae-dbxaml-dev \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --target-port 80 \
  --ingress 'internal'
```

2. **Configure Application Gateway** (optional):
   - Set up Application Gateway for external access
   - Point backend to ACA environment static IP

### For AKS

1. **Get Credentials**:
```bash
# Adjust RG name: rg-{env}-{project}-shared
az aks get-credentials \
  --resource-group rg-dev-dbxaml-shared \
  --name aks-dbxaml-dev
```

2. **Deploy Workloads**:
```bash
# Deploy to user pool with toleration
kubectl apply -f my-deployment.yaml
```

Example deployment with toleration:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inference-app
spec:
  template:
    spec:
      tolerations:
      - key: "workload"
        operator: "Equal"
        value: "inference"
        effect: "NoSchedule"
      containers:
      - name: app
        image: myacr.azurecr.io/inference:latest
```

## Best Practices

### Azure Container Apps
1. **Use internal ingress** for services that don't need public access
2. **Configure health probes** for all apps
3. **Set resource limits** appropriately
4. **Use Dapr** for service-to-service communication
5. **Enable zone redundancy** for production workloads

### AKS
1. **Use workload identity** instead of service principals
2. **Implement pod security policies** using Azure Policy
3. **Configure horizontal pod autoscaling** for workloads
4. **Use tainted node pools** for specialized workloads
5. **Enable monitoring** and configure alerts

## Integration with Azure ML

Both AKS and ACA can be used for Azure ML inference endpoints:

### AKS Integration
- Configure as Azure ML compute target
- Deploy models as managed online endpoints
- Use for batch inference

### ACA Integration  
- Deploy ML models as container apps
- Use for serverless inference
- Integrate with Azure ML pipelines

## Cost Optimization

### Azure Container Apps
- Consumption plan scales to zero
- Pay only for actual usage
- Consider dedicated workload profiles for predictable loads

### AKS
- User pool can scale to zero
- Use spot instances for non-critical workloads
- Right-size VM SKUs based on actual usage
- Consider cluster autoscaler settings

## Troubleshooting

### ACA Issues
- Check environment creation status
- Verify subnet delegation
- Ensure /23 or larger subnet
- Review Log Analytics workspace connectivity

### AKS Issues
- Verify private DNS resolution
- Check node pool status
- Review Log Analytics integration
- Validate workload identity configuration

## References

- [Azure Container Apps Landing Zone Accelerator](https://aka.ms/aca-lza)
- [AKS Secure Baseline](https://github.com/Azure/AKS-Landing-Zone-Accelerator)
- [Azure ML with AKS](https://learn.microsoft.com/azure/machine-learning/how-to-deploy-kubernetes-online-endpoint)
- [Container Apps Private Networking](https://learn.microsoft.com/azure/container-apps/networking)
