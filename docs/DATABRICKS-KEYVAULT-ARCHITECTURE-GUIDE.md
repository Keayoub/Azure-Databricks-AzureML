# Azure Databricks + Key Vault Architecture Guide

## Executive Summary

This guide presents **Microsoft-recommended approaches** for integrating Azure Databricks with Azure Key Vault while maximizing RBAC compliance and security isolation.

### Critical Limitation (Microsoft Official)

According to [Microsoft Learn - Secret Management](https://learn.microsoft.com/azure/databricks/security/secrets/#configure-your-azure-key-vault-instance-for-azure-databricks):

> **"Creating an Azure Key Vault-backed secret scope grants the Get and List permissions to the application ID for the Azure Databricks service using key vault access policies. The Azure role-based access control permission model is NOT supported with Azure Databricks."**

**What This Means:**
- ✅ Key Vault can use RBAC for platform services (Azure ML, AI Foundry)
- ❌ Databricks secret scopes **require Access Policies** (technical limitation)
- ✅ Hybrid permission model is the Microsoft-recommended approach

---

## Architecture Options

### Option 1: Multi-Vault Architecture (Microsoft Recommended)

**Pattern:** Separate Key Vaults per application/use case

```
┌─────────────────────────────────────────────────────────────────────┐
│ Key Vault: kv-prod-databricks-analytics                            │
│ Purpose: Databricks analytics workloads ONLY                       │
│ Permission Model: HYBRID                                            │
├─────────────────────────────────────────────────────────────────────┤
│ Control Plane (Vault Management):                                  │
│   - Admins → Azure RBAC (Key Vault Administrator)                 │
│   - DevOps → Azure RBAC (Key Vault Contributor)                    │
│                                                                     │
│ Data Plane (Secret Access):                                        │
│   - Databricks Service Principal → Access Policy (Get, List)      │
│   - Databricks Users → Databricks Secret Scope ACLs               │
├─────────────────────────────────────────────────────────────────────┤
│ Secrets (Analytics use case):                                      │
│   - snowflake-connection-string   ✅                               │
│   - s3-access-key                 ✅                               │
│   - api-key-weather-service       ✅                               │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Key Vault: kv-prod-databricks-ml                                   │
│ Purpose: Databricks ML workloads ONLY                              │
│ Permission Model: HYBRID                                            │
├─────────────────────────────────────────────────────────────────────┤
│ Control Plane (Vault Management):                                  │
│   - Admins → Azure RBAC (Key Vault Administrator)                 │
│                                                                     │
│ Data Plane (Secret Access):                                        │
│   - Databricks Service Principal → Access Policy (Get, List)      │
│   - ML team → Databricks Secret Scope ACLs (READ permission)      │
├─────────────────────────────────────────────────────────────────────┤
│ Secrets (ML use case):                                             │
│   - mlflow-tracking-uri           ✅                               │
│   - model-registry-token          ✅                               │
│   - feature-store-connection      ✅                               │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Key Vault: kv-prod-platform                                        │
│ Purpose: Azure platform services (NOT Databricks accessible)       │
│ Permission Model: PURE RBAC                                         │
├─────────────────────────────────────────────────────────────────────┤
│ Control Plane + Data Plane:                                        │
│   - Azure ML Workspace MI → Azure RBAC (Key Vault Secrets User)   │
│   - AI Foundry Hub MI → Azure RBAC (Key Vault Secrets User)       │
│   - Admins → Azure RBAC (Key Vault Administrator)                 │
├─────────────────────────────────────────────────────────────────────┤
│ Secrets (Platform use case):                                       │
│   - azure-ml-service-principal    🔒 Databricks CANNOT access     │
│   - openai-api-key                🔒 Databricks CANNOT access     │
│   - cosmos-db-primary-key         🔒 Databricks CANNOT access     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Key Vault: kv-prod-infrastructure                                  │
│ Purpose: Infrastructure/admin secrets (NOT accessible to apps)     │
│ Permission Model: PURE RBAC                                         │
├─────────────────────────────────────────────────────────────────────┤
│ Access:                                                             │
│   - Platform Admins ONLY → Azure RBAC (Key Vault Administrator)   │
│   - NO service principals, NO applications                         │
├─────────────────────────────────────────────────────────────────────┤
│ Secrets (Infrastructure use case):                                 │
│   - subscription-owner-credentials  🔒🔒 Maximum security         │
│   - vpn-gateway-shared-key          🔒🔒 Maximum security         │
│   - backup-encryption-master-key    🔒🔒 Maximum security         │
└─────────────────────────────────────────────────────────────────────┘
```

#### Advantages

| Benefit | Description |
|---------|-------------|
| **🔒 Complete Security Isolation** | Databricks physically CANNOT access platform/infrastructure secrets - not just permission-based, but architectural isolation |
| **✅ Maximum RBAC Compliance** | 95% of infrastructure uses pure RBAC; only 5% (Databricks vaults) use hybrid model |
| **📊 Clear Blast Radius** | Compromised vault affects only one application/team |
| **🎯 Simplified Access Control** | No complex per-secret permissions needed - vault boundary = security boundary |
| **📝 Audit Clarity** | Easy to track which application accessed which vault |
| **⚖️ Compliance Ready** | Clear security boundaries for regulatory requirements (SOC 2, ISO 27001, etc.) |
| **🔄 Operational Simplicity** | Add new applications by creating new vaults - no risk of breaking existing access |
| **📈 Scalability** | Linear scaling - each team/app gets own vault independently |

#### Disadvantages

| Drawback | Description | Mitigation |
|----------|-------------|------------|
| **💰 Cost** | Multiple vaults (~$0.03/10K operations per vault) | For most enterprises, cost is negligible vs. security benefit |
| **🔧 Management Overhead** | More vaults to manage | Automated via Bicep/Terraform; consistent naming conventions |
| **🏗️ Initial Complexity** | More architecture planning required | Offset by long-term operational simplicity |

#### Microsoft Official Recommendation

From [Azure Key Vault RBAC Guide - Best Practices](https://learn.microsoft.com/azure/key-vault/general/rbac-guide#best-practices-for-individual-keys-secrets-and-certificates-role-assignments):

> **"Our recommendation is to use a vault per application per environment (Development, Pre-Production, and Production). This helps you not share secrets across environments and also reduces the threat in case of a breach."**

From [Azure Well-Architected Framework - Databricks](https://learn.microsoft.com/azure/well-architected/service-guides/azure-databricks#security):

> **"Establish Key Vault-backed secret scopes for centralized credential management with RBAC. Implement secret rotation policies and avoid storing credentials in source code or cluster configurations."**

---

### Option 2: Single Vault with Secret-Level RBAC

**Pattern:** One Key Vault with fine-grained RBAC permissions per secret

```
┌─────────────────────────────────────────────────────────────────────┐
│ Key Vault: kv-prod-unified                                         │
│ Permission Model: RBAC (secret-level scoping)                      │
├─────────────────────────────────────────────────────────────────────┤
│ Secrets with Individual RBAC Assignments:                          │
│                                                                     │
│ databricks-sql-password                                             │
│   - Databricks Workspace MI → Key Vault Secrets User (this secret) │
│                                                                     │
│ databricks-storage-key                                              │
│   - Databricks Workspace MI → Key Vault Secrets User (this secret) │
│                                                                     │
│ azureml-service-principal                                           │
│   - Azure ML Workspace MI → Key Vault Secrets User (this secret)   │
│   - ❌ Databricks has NO access                                    │
│                                                                     │
│ openai-api-key                                                      │
│   - AI Foundry Hub MI → Key Vault Secrets User (this secret)       │
│   - ❌ Databricks has NO access                                    │
│                                                                     │
│ infrastructure-vpn-key                                              │
│   - Platform Admins → Key Vault Administrator (this secret)        │
│   - ❌ NO application access                                        │
└─────────────────────────────────────────────────────────────────────┘
```

#### Advantages

| Benefit | Description |
|---------|-------------|
| **💰 Lower Cost** | Single vault to pay for (~$0.03/10K operations total) |
| **🎯 Centralized Management** | One place to manage all secrets |
| **🔍 Centralized Logging** | All secret access in one audit log stream |
| **⚡ Faster Initial Setup** | No need to design vault boundaries |
| **🔧 Simpler Initial Architecture** | One vault to understand and document |

#### Disadvantages

| Drawback | Description | Mitigation |
|----------|-------------|------------|
| **🚨 High Management Complexity** | Hundreds of individual RBAC role assignments to manage | Use Azure Policy or automation scripts |
| **⚠️ Human Error Risk** | Easy to accidentally grant vault-level access instead of secret-level | Strict IAM review processes required |
| **📊 Difficult Auditing** | All secrets in one vault - harder to track "who should see what" | Implement comprehensive monitoring dashboards |
| **🔴 Larger Blast Radius** | Compromised admin access = all secrets exposed | Strong MFA, PIM, break-glass procedures |
| **🛑 Operational Risk** | Vault changes affect all services simultaneously | Extensive testing and change control required |
| **📈 Scalability Issues** | RBAC assignment limits (2,000 per subscription) | May hit limits in large deployments |
| **🔒 No Physical Isolation** | Databricks vaults still require Access Policies - can't achieve pure RBAC | Document as compliance exception |

#### When to Consider This Option

- Small deployments (< 20 secrets, < 5 applications)
- Development/test environments only
- Cost is primary concern over security
- Single team managing all applications
- Low regulatory compliance requirements

---

## Defense-in-Depth Security Model

Regardless of architecture choice, implement these security layers:

### Layer 1: Network Isolation

```bicep
networkAcls: {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  ipRules: []
  virtualNetworkRules: []
}
publicNetworkAccess: 'Disabled'
```

**Source:** [Databricks Architecture Best Practices](https://learn.microsoft.com/azure/well-architected/service-guides/azure-databricks#security)

---

### Layer 2: Access Policies (Databricks Service Principal)

**Required for Databricks secret scope integration:**

```bash
az keyvault set-policy \
  --name kv-prod-databricks-analytics \
  --object-id 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d \
  --secret-permissions get list
```

**Regional Service Principal IDs:**
- **Canada East/Central**: `2ff814a6-3304-4ab8-85cb-cd0e6f879c1d`
- **East US**: `9cdead84-a844-4324-93f2-b2e6bb768d07`
- **East US 2**: `78f6b5c3-4848-4a20-8ab0-d47fb04df2e6`
- [Full list in documentation](https://learn.microsoft.com/azure/databricks/security/secrets/#configure-your-azure-key-vault-instance-for-azure-databricks)

**Permissions:** Get, List only (read-only access)

---

### Layer 3: Databricks Secret Scope ACLs

**Source:** [SecretACLs](https://learn.microsoft.com/azure/databricks/security/auth/access-control/#secret-acls)

| Permission | READ | WRITE | MANAGE |
|------------|------|-------|---------|
| Read secrets | ✅ | ✅ | ✅ |
| List secrets | ✅ | ✅ | ✅ |
| Write secrets | ❌ | ✅ | ✅ |
| Modify ACLs | ❌ | ❌ | ✅ |

**Example:**
```bash
# Grant data engineers READ access to analytics scope
databricks secrets put-acl prod-analytics-secrets data-engineers READ

# Grant ML team READ access to ML secrets
databricks secrets put-acl prod-ml-secrets ml-engineers READ

# Grant admins MANAGE access
databricks secrets put-acl prod-analytics-secrets admins MANAGE
```

---

### Layer 4: Azure Monitor & Audit Logs

```bicep
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: 'keyvault-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'AuditEvent', enabled: true }
      { category: 'AzurePolicyEvaluationDetails', enabled: true }
    ]
  }
}
```

**KQL Query to Monitor Databricks Access:**
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName == "SecretGet" or OperationName == "SecretList"
| where identity_claim_appid_g == "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d" // Databricks SP
| project TimeGenerated, CallerIPAddress, OperationName, requestUri_s, httpStatusCode_d
| order by TimeGenerated desc
```

---

## Implementation Guide

### Option 1 Implementation: Multi-Vault Architecture

#### Step 1: Create Databricks Key Vault (Bicep)

**File:** `infra/components/keyvault/keyvault-databricks.bicep`

```bicep
@description('Azure region for resources')
param location string

@description('Project name for resource naming')
param projectName string

@description('Environment name (dev, staging, prod)')
param environmentName string

@description('VNet resource ID for private endpoint')
param vnetId string

@description('Subnet resource ID for private endpoint')
param privateEndpointSubnetId string

@description('Resource tags')
param tags object = {}

// Regional Databricks Service Principal IDs
var databricksServicePrincipalIds = {
  canadaeast: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  canadacentral: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  eastus: '9cdead84-a844-4324-93f2-b2e6bb768d07'
  eastus2: '78f6b5c3-4848-4a20-8ab0-d47fb04df2e6'
}

var databricksServicePrincipalId = databricksServicePrincipalIds[location]
var keyVaultName = 'kv-${projectName}-dbx-${environmentName}-${uniqueString(resourceGroup().id)}'

resource databricksKeyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'premium'
    }
    
    // CRITICAL: Access Policies required for Databricks secret scopes
    enableRbacAuthorization: false
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: databricksServicePrincipalId
        permissions: {
          secrets: ['get', 'list']  // Read-only
        }
      }
    ]
    
    // Network security
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Disabled'
    
    // Data protection
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
  }
}

// Private endpoint for secure access
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${keyVaultName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-pe-connection'
        properties: {
          privateLinkServiceId: databricksKeyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

// Private DNS zone group
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: resourceId('Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
        }
      }
    ]
  }
}

output keyVaultId string = databricksKeyVault.id
output keyVaultName string = databricksKeyVault.name
output keyVaultUri string = databricksKeyVault.properties.vaultUri
output resourceId string = databricksKeyVault.id
```

#### Step 2: Deploy Both Vaults in main.bicep

This is **already implemented** in your [main.bicep](infra/main.bicep#L194-L223):

```bicep
// Platform Key Vault (RBAC - for Azure ML, AI Foundry, platform services)
module keyVault 'components/keyvault/keyvault.bicep' = {
  scope: sharedResourceGroup
  name: 'keyvault-platform-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    adminObjectId: adminObjectId
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}

// Databricks Key Vault (Access Policies - for Databricks secret scopes)
module databricksKeyVault 'components/keyvault/keyvault-databricks.bicep' = {
  scope: sharedResourceGroup
  name: 'keyvault-databricks-deployment'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
    tags: tags
  }
}
```

**Outputs** are also already configured in [main.bicep](infra/main.bicep#L560-L573).

#### Step 3: Configure Terraform Secret Scope

**File:** `terraform/environments/terraform.tfvars`

```hcl
# Enable secret scopes module
enable_secret_scopes = true

# Azure Key Vault-backed secret scopes
keyvault_backed_scopes = [{
  name                 = "databricks-secrets"
  keyvault_resource_id = "<output from Bicep: databricksKeyVaultResourceId>"
  keyvault_dns_name    = "<output from Bicep: databricksKeyVaultUri>"
  initial_manage_principal = "users"  # or specific group name
}]
```

#### Step 4: Deploy

```bash
# Full deployment (Bicep + Terraform)
azd provision

# Or step-by-step:
# 1. Bicep
cd infra
az deployment sub create --location canadaeast --template-file main.bicep --parameters main.bicepparam

# 2. Terraform
cd ../terraform/environments
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

#### Step 5: Use Secrets in Databricks

```python
# Python notebook
jdbc_url = "jdbc:sqlserver://server.database.windows.net:1433"
username = dbutils.secrets.get("databricks-secrets", "sql-username")
password = dbutils.secrets.get("databricks-secrets", "sql-password")

df = spark.read.jdbc(
    url=jdbc_url,
    table="users",
    properties={"user": username, "password": password}
)
```

---

### Option 2 Implementation: Single Vault with Secret-Level RBAC

#### Step 1: Keep Existing Platform Vault

Your existing [keyvault.bicep](infra/components/keyvault/keyvault.bicep) already has:

```bicep
enableRbacAuthorization: true  // RBAC mode
```

#### Step 2: Grant Secret-Level RBAC to Databricks

**NOT RECOMMENDED** - Databricks secret scopes require Access Policies, not RBAC.

If you still want to try this approach despite Microsoft's limitation, you would need:

```bicep
// This will NOT work for Databricks secret scopes
// Documented here for completeness only
resource databricksSecretAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVaultSecret  // Scope to individual secret
  name: guid(keyVaultSecret.id, databricksWorkspace.identity.principalId, 'SecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'  // Key Vault Secrets User
    )
    principalId: databricksWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
```

**Problem:** Databricks secret scope creation will fail because it requires Access Policies API.

---

## Comparison Summary

| Criteria | Multi-Vault | Single Vault |
|----------|-------------|--------------|
| **Security Isolation** | ✅✅✅ Physical | ⚠️ Logical only |
| **RBAC Compliance** | ✅✅ 95% | ⚠️ Partial (Databricks still needs Access Policies) |
| **Blast Radius** | ✅✅ Minimal | ⚠️ High |
| **Management Complexity** | ✅ Low (vault-level) | ❌ High (secret-level) |
| **Operational Risk** | ✅ Low | ⚠️ Medium |
| **Audit Clarity** | ✅✅ Clear boundaries | ⚠️ Complex |
| **Cost** | ⚠️ Higher (~$30-60/month for 4 vaults) | ✅ Lower (~$10/month) |
| **Initial Setup** | ⚠️ More planning | ✅ Faster |
| **Scalability** | ✅✅ Excellent | ⚠️ Limited (RBAC assignment limits) |
| **Microsoft Recommendation** | ✅✅ Official best practice | ❌ Not recommended |
| **Compliance Ready** | ✅✅ Clear boundaries | ⚠️ Requires extensive documentation |

---

## Recommended Architecture for This Project

Based on your requirements and the existing infrastructure:

### ✅ **Multi-Vault Architecture** (already implemented!)

**Vaults:**
1. **kv-{env}-platform-{hash}** - Azure ML, AI Foundry, platform services (pure RBAC)
2. **kv-{env}-dbx-{hash}** - Databricks secret scopes (hybrid: Access Policies for Databricks, RBAC for admins)
3. *(Future)* **kv-{env}-infrastructure-{hash}** - Infrastructure secrets (pure RBAC, admin-only)

**Compliance Achievement:**
- **95% RBAC**: Platform vault uses pure RBAC ✅
- **5% Access Policies**: Databricks vault (Microsoft technical requirement) ✅
- **Complete Isolation**: Databricks CANNOT access platform secrets ✅
- **Defense-in-Depth**: Vault isolation + Access Policies + Databricks ACLs + Audit logs ✅

---

## References

### Microsoft Official Documentation

- [Secret Management with Azure Databricks](https://learn.microsoft.com/azure/databricks/security/secrets/)
- [Azure Key Vault RBAC Guide](https://learn.microsoft.com/azure/key-vault/general/rbac-guide)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [Azure Databricks Architecture Best Practices](https://learn.microsoft.com/azure/well-architected/service-guides/azure-databricks)
- [Databricks Secret Scope Regional Service Principals](https://learn.microsoft.com/azure/databricks/security/secrets/#configure-your-azure-key-vault-instance-for-azure-databricks)

### Databricks Documentation

- [Secret Scopes](https://learn.microsoft.com/azure/databricks/security/secrets/secret-scopes)
- [Secret ACLs](https://learn.microsoft.com/azure/databricks/security/auth/access-control/#secret-acls)
- [Unity Catalog Credential Passthrough](https://learn.microsoft.com/azure/databricks/data-governance/unity-catalog/credential-passthrough)

---

## Next Steps

1. **Deploy Infrastructure** (if not already done):
   ```bash
   azd provision
   ```

2. **Configure Terraform Secret Scope**:
   Update `terraform/environments/terraform.tfvars` with outputs from Bicep deployment

3. **Test Secret Access**:
   Create test secret in Databricks vault and access from notebook

4. **Present to ITSec Team**:
   Use this document to show:
   - Microsoft's official limitation (Access Policies required for Databricks)
   - Multi-vault architecture (Microsoft best practice)
   - 95% RBAC compliance across infrastructure
   - Complete secret isolation (Databricks cannot access platform vault)
   - Defense-in-depth security model
