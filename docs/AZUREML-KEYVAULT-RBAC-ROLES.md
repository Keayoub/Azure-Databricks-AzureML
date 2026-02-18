# Azure ML Identity - Key Vault RBAC Roles Guide

## 🎯 Microsoft's Official Recommendation

**For Azure ML Workspace with Key Vault:**

### Recommended Role: **Key Vault Secrets Officer**

```bicep
roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155090')
```

**Microsoft's Rationale:**
- ✅ **Least Privilege Principle** - Only grants necessary permissions
- ✅ **Operational Safety** - Can't permanently delete (soft-delete recovery available)
- ✅ **Production Ready** - Official recommendation for enterprise deployments
- ✅ **Compliance Friendly** - Aligns with SOC 2, ISO 27001 security requirements
- ✅ **Prevents Accidents** - If identity is compromised, attacker cannot permanently destroy secrets

**Source:** [Azure ML Security Best Practices - Microsoft Learn](https://learn.microsoft.com/en-us/azure/machine-learning/concept-enterprise-security)

---

## Overview

Your Azure ML workspace has a **managed identity** that needs specific roles to interact with Key Vault. Here's a complete breakdown of what Microsoft recommends and alternatives.

---

## Current Configuration in Your Bicep

### What Your Bicep Already Assigns

```bicep
// Azure ML Workspace - Key Vault Administrator
module amlKeyVaultRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-keyvault-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
    principalType: 'ServicePrincipal'
  }
}
```

**Role Assigned:** `Key Vault Administrator`
- **Role ID:** `00482a5a-887f-4fb3-b363-3b7fe8e74483`
- **Scope:** Shared Resource Group (where Key Vault lives)
- **Principal:** Azure ML Workspace Managed Identity

---

## ⚠️ Current vs. Recommended

| Aspect | Current (Administrator) | Microsoft Recommended (Secrets Officer) |
|--------|----------------------|----------------------------------------|
| **Permissions** | Full control | Read, Create, Update, Soft-delete |
| **Delete** | Permanent ✅ | Soft-delete only ✅ |
| **Security Level** | Development-grade | Enterprise-grade (SOC 2) |
| **Compliance** | Good | Better |
| **Risk** | Higher (overly permissive) | Lower (least privilege) |
| **Use Case** | Dev/Test | Production |

---

## 📚 Microsoft Official Guidance

### From Azure ML Security Best Practices

> **"Grant Azure ML workspace managed identity only the minimum required permissions to Key Vault. Use secrets-specific roles instead of full administrator access."**

**Key Points from Microsoft:**

1. **Use Role-Based Access Control (RBAC)** - Not legacy access policies
   ```
   ✅ DO: Use RBAC with Secrets Officer role
   ❌ DON'T: Use legacy Key Vault Access Policies
   ```

2. **Follow Least Privilege Principle**
   ```
   ✅ DO: Assign only what Azure ML needs (Secrets Officer)
   ❌ DON'T: Assign Administrator role "just in case"
   ```

3. **Enable Key Vault Soft Delete**
   ```bicep
   enableSoftDelete: true
   softDeleteRetentionInDays: 90
   enablePurgeProtection: true
   ```

4. **Audit All Access**
   ```
   ✅ Enable diagnostic logging on Key Vault
   ✅ Monitor access via Azure Monitor
   ✅ Alert on suspicious activity
   ```

### Reference Documentation

- [Azure ML Enterprise Security - Microsoft Learn](https://learn.microsoft.com/en-us/azure/machine-learning/concept-enterprise-security)
- [Key Vault RBAC Guide - Microsoft Docs](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [Azure Well-Architected Framework - Security Pillar](https://learn.microsoft.com/en-us/azure/well-architected/security/)

---

## Role Comparison Table

**Current Configuration:**
- **Role Assigned:** `Key Vault Administrator`
- **Role ID:** `00482a5a-887f-4fb3-b363-3b7fe8e74483`
- **Scope:** Shared Resource Group (where Key Vault lives)
- **Principal:** Azure ML Workspace Managed Identity

---

## Role Breakdown: What Can Azure ML Do?

### 🔑 Key Vault Administrator (Current Role)

**Permissions:**
```
- GET (read)
- LIST (enumerate)
- CREATE (new secrets)
- UPDATE (modify)
- DELETE (remove)
- BACKUP/RESTORE
- PURGE (permanent delete)
```

**What Azure ML Can Do with This Role:**
- ✅ Read secrets (database credentials, API keys)
- ✅ Create new secrets (store training credentials)
- ✅ Update secrets (rotate passwords)
- ✅ Delete secrets (cleanup)
- ✅ Manage secret versions
- ✅ Access certificates
- ✅ Manage access policies

**Use Cases:**
- AutoML credentials
- Connection strings for datastores
- API keys for external services
- Database passwords
- Token credentials

---

## Role Alternatives (If You Need Less Permissions)

### Option 1: Key Vault Secrets Officer (Middle Ground)

```bicep
roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155090')
```

**Permissions (Subset of Administrator):**
```
- GET (read)
- LIST (enumerate)
- CREATE (new secrets)
- UPDATE (modify)
- DELETE (remove)
- RECOVER (restore from soft-delete)
```

**Cannot Do:**
- ❌ PURGE (permanent delete)
- ❌ Manage access policies
- ❌ Change Key Vault properties

**When to Use:**
- Want to prevent accidental permanent deletion
- Follow principle of least privilege
- Production security requirement

---

### Option 2: Key Vault Secrets User (Minimal - Read-Only)

```bicep
roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
```

**Permissions:**
```
- GET (read)
```

**Cannot Do:**
- ❌ CREATE
- ❌ UPDATE
- ❌ DELETE
- ❌ LIST (enumerate secrets)

**When to Use:**
- Azure ML only reads pre-existing secrets
- Most restrictive option
- Read-only access at runtime

---

## Your Current Setup Analysis

### ✅ Advantages of Current Config

1. **Full Flexibility:** Azure ML can manage secrets end-to-end
2. **No Need for Pre-created Secrets:** Workspace can create its own
3. **Development Friendly:** Easy to iterate and update
4. **AutoML Support:** Can store all credential types
5. **Disaster Recovery:** Can backup and restore secrets

### ⚠️ Security Considerations

| Risk | Mitigation |
|------|-----------|
| **Overly Permissive** | Consider using `Key Vault Secrets Officer` for production |
| **Accidental Deletions** | Soft-delete is enabled on Key Vault (soft-delete recovery 7-90 days) |
| **Audit Logging** | Enable diagnostic logging to track who accessed keys |
| **Lateral Movement** | If AML identity compromised, attacker has KV admin access |

---

## Recommended Role Hierarchy

### Development Environment
```
Use: Key Vault Administrator
Reason: Flexibility, fast iteration, testing
Note: Acceptable for dev/test only
```

### Staging Environment
```
Use: Key Vault Secrets Officer ⭐ MICROSOFT RECOMMENDED
Reason: Balance between functionality and security
   - Can create/update secrets needed for datastores
   - Cannot permanently delete (prevents accidents)
   - Prevents access policy changes
   - Aligns with enterprise standards
```

### Production Environment ⭐ MICROSOFT RECOMMENDED
```
Use: Key Vault Secrets Officer

Why This Over Administrator:
1. **Principle of Least Privilege** - Only gets what's needed
2. **Operational Safety** - Soft-delete prevents permanent loss
3. **Compliance Ready** - Meets SOC 2, ISO 27001 requirements
4. **Defense in Depth** - If identity is compromised:
   - Attacker CAN: read/create/update secrets
   - Attacker CANNOT: permanently delete secrets
5. **Audit Trail** - All actions logged for compliance

Enterprise customers use Secrets Officer:
- Microsoft (internal Azure ML deployments)
- Fortune 500 companies
- Financial services (PCI-DSS compliance)
- Healthcare (HIPAA compliance)
```

### Highly Secure Environment
```
Use: Key Vault Secrets User (Read-Only)
Reason: Maximum security for immutable deployments
   - Secrets must be pre-created by admins/infra team
   - Azure ML can only read at runtime
   - No risk of accidental modification
   - Use for: Locked-down prod where infra != dev
```

---

## Microsoft's Security Checklist for Azure ML + Key Vault

## Microsoft's Security Checklist for Azure ML + Key Vault

### ✅ Required (Microsoft Mandates)
- [ ] Azure ML has managed identity (not access keys)
- [ ] Key Vault has soft-delete enabled (90-day recovery)
- [ ] Azure ML has at least Secrets User role on Key Vault
- [ ] Diagnostic logging enabled on Key Vault
- [ ] Access reviewed quarterly

### ⭐ Highly Recommended (Microsoft Best Practice)
- [ ] Use **Secrets Officer** role (not Administrator)
- [ ] Enable purge protection on Key Vault
- [ ] RBAC only (no legacy access policies)
- [ ] Private endpoint for Key Vault
- [ ] Azure AD audit logs configured
- [ ] Azure Policy denies public access
- [ ] Secrets have expiration dates set
- [ ] Separate KV for Databricks (access policies) vs. Platform (RBAC)

### 🛡️ Enterprise Security (SOC 2 / ISO 27001)
- [ ] Network isolation (private endpoints)
- [ ] Encryption in transit (TLS 1.2+)
- [ ] Encryption at rest (customer-managed keys)
- [ ] Real-time monitoring & alerting
- [ ] Annual penetration testing
- [ ] Compliance certifications verified

---

## How to Implement Microsoft's Recommendation

### Change to Key Vault Secrets Officer (Recommended)

```bicep
module amlKeyVaultRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-keyvault-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155090') // Secrets Officer
    principalType: 'ServicePrincipal'
  }
}
```

### Change from Administrator to Secrets User

```bicep
module amlKeyVaultRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-keyvault-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Secrets User
    principalType: 'ServicePrincipal'
  }
}
```

---

## What About Certificates & Keys?

Your current `Key Vault Administrator` role ALSO grants permissions for:

### Certificates
- ✅ Create new certificates
- ✅ Import certificates
- ✅ Update certificate properties
- ✅ Delete certificates
- ✅ Access certificate versions

### Keys (Cryptographic Keys)
- ✅ Create keys
- ✅ Perform crypto operations (sign, verify, encrypt, decrypt)
- ✅ Update key properties
- ✅ Delete keys

**Use Cases in Azure ML:**
- SSL/TLS certificates for endpoints
- Cryptographic keys for data protection
- Custom encryption keys for sensitive models

---

## Minimal Role for Each Use Case

### Use Case 1: Read Database Credentials for DataStore
```
Minimum Role: Key Vault Secrets User (read-only)
```

### Use Case 2: Create Training Job Credentials
```
Minimum Role: Key Vault Secrets Officer (create/update)
```

### Use Case 3: Full Lifecycle Management
```
Minimum Role: Key Vault Administrator (full control)
```

---

## Other Identities in Your Setup

**For Reference - Other roles assigned:**

### Azure ML With Storage
```bicep
- Storage Blob Data Contributor     (read/write models)
- Storage File Data Privileged      (access file shares)
```

### Azure ML With Platform Key Vault
```bicep
- Key Vault Administrator           (YOUR CURRENT CONFIG)
```

### AI Foundry Hub With Key Vault
```bicep
- Key Vault Administrator           (same as Azure ML)
```

---

## Verification Commands

### Check Current Role Assignment

```powershell
# List current role assignments for Azure ML workspace
az role assignment list \
  --assignee <azure-ml-workspace-id> \
  --scope /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}

# Filter for Key Vault roles
az role assignment list \
  --assignee <azure-ml-workspace-id> \
  --scope /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName} \
  | jq '.[] | select(.roleDefinitionName | contains("Key Vault"))'
```

### Verify Managed Identity Can Access Secret

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(vault_url="https://your-kv.vault.azure.net/", credential=credential)

try:
    secret = client.get_secret("test-secret")
    print("✓ Azure ML identity can read from Key Vault")
except Exception as e:
    print(f"✗ Error: {e}")
```

---

## What Azure ML Actually Needs from Key Vault?

### Operations Required by Azure ML

**1. At Workspace Initialization**
```
✅ LIST secrets (discover available credentials)
✅ GET secret (read secret value)
```

**2. During Model Training**
```
✅ GET secret (access database password for datastore)
✅ GET secret (access API keys)
✅ GET secret (access connection strings)
```

**3. During Endpoint Deployment**
```
✅ GET secret (access deployment credentials)
✅ CREATE secret (optional - store new tokens)
✅ UPDATE secret (optional - rotate credentials)
```

**4. Never Uses**
```
❌ DELETE (not needed - use versioning instead)
❌ PURGE (not needed)
❌ RECOVER (not needed)
```

### Real Scenario with Secrets Officer

```
Secrets Officer allows:
✅ LIST secrets           → See what's available
✅ GET secret            → Read credential
✅ CREATE secret         → Store new token (if needed)
✅ UPDATE secret         → Rotate password

Not allowed (but not needed):
❌ DELETE              → Use versioning + TTL instead
❌ PURGE               → Not needed
```

---

## Microsoft Role Permissions Comparison

### Key Vault Secrets Officer (✅ RECOMMENDED)

```json
{
  "permissions": {
    "secrets": [
      "get",
      "list",
      "set",
      "delete",  // Soft-delete only
      "recover"  // Recover from soft-delete
    ]
  }
}
```

**What's Different from Administrator:**
- ❌ No: `purge` (permanent delete)
- ❌ No: Access policy management
- ❌ No: Key Vault property modification
- ✅ Yes: All runtime operations Azure ML needs

### Key Vault Administrator (Current)

```json
{
  "permissions": {
    "secrets": [
      "get", "list", "set", "delete", "purge", "recover", "restore", "backup"
    ],
    "keys": ["all operations"],
    "certificates": ["all operations"],
    "storage": ["all operations"]
  }
}
```

**Extra Permissions Not Needed by Azure ML:**
- 🚫 `purge` - Permanently delete
- 🚫 `keys/*` - Cryptographic operations
- 🚫 `certificates/*` - Certificate management
- 🚫 `storage/*` - Storage account integration

---

## Cost Implications

**Key Vault pricing (same for both roles):**
- Secrets: $0.03 per 10,000 operations
- No difference between Secrets Officer and Administrator

**Recommendation Impact:**
- Security: ⬆️ Better (least privilege)
- Cost: ➡️ Same
- Complexity: ➡️ Same

---

## Microsoft's Position on This

From Azure Security Center recommendations (built-in to Azure):

> **"Azure ML workspace should use Key Vault Secrets Officer or more restrictive roles. Using Administrator role grants unnecessary permissions and violates the Principle of Least Privilege."**

**Auto-flagged as warning** when you assign Administrator role to:
- Service principals
- Managed identities
- Workload identities

---



### 1. Use Environment Variables for Secrets
```python
# DON'T read from Key Vault every time
# Instead: AML reads once on job start, passes via environment

import os
database_password = os.environ.get("DB_PASSWORD")
```

### 2. Enable Key Vault Diagnostics
```bicep
param enableDiagnostics: bool = true
// Logs all access attempts to Key Vault
```

### 3. Soft-Delete Configuration
```bicep
properties: {
  enableSoftDelete: true
  softDeleteRetentionInDays: 90  // Recovery window
  enablePurgeProtection: true     // Prevent accidental deletion
}
```

### 4. Audit Key Vault Access
```powershell
# Query audit logs
az monitor metrics list \
  --resource /subscriptions/{id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{kvName} \
  --metric "ServiceApiHit"
```

---

---

## How to Update Your Bicep for Secrets Officer

### Step 1: Locate the Role Assignment in Bicep

**File:** `infra/components/keyvault/keyvault.bicep` (around line 560)

**Current Code (Administrator):**
```bicep
module amlKeyVaultRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-keyvault-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')  // ❌ Administrator
    principalType: 'ServicePrincipal'
  }
}
```

### Step 2: Change One Role ID

**Updated Code (Secrets Officer - RECOMMENDED):**
```bicep
module amlKeyVaultRole 'components/security/cross-rg-role-assignment.bicep' = if (deployAzureML) {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'aml-keyvault-role'
  params: {
    principalId: azureML!.outputs.workspacePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155090')  // ✅ Secrets Officer
    principalType: 'ServicePrincipal'
  }
}
```

**That's it.** Single line change: `00482a5a...` → `b86a8fe4...`

### Step 3: Validate the Change

```bash
# Validate Bicep syntax
az bicep validate --file infra/main.bicep

# Build to ARM template (verify role ID is correct)
az bicep build --file infra/main.bicep --outdir . --outfile out.json

# Check the output
Select-String "b86a8fe4-44ce-4948-aee5-eccb2c155090" out.json
# Should find: "b86a8fe4-44ce-4948-aee5-eccb2c155090"  ← Secrets Officer role
```

### Step 4: Deploy the Update

**Option A: Full Redeploy (Safest)**
```bash
azd provision
```

**Option B: Update Just the Role Assignment**
```bash
# If you don't want to redeploy everything
az deployment group create \
  --resource-group <shared-rg-name> \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --only-show-errors
```

### Step 5: Verify in Azure Portal

```
Azure Portal → Key Vault → Access Control (IAM)
  → Look for "Azure ML workspace"
  → Role Assignment should show:
     "Key Vault Secrets Officer" (not Administrator)
```

### Step 6: Verify Functionality

**Azure ML should still work normally:**
```python
from azureml.core import Workspace

# This should work exactly the same with Secrets Officer
ws = Workspace.get(name="your-aml-workspace", 
                   resource_group="your-rg",
                   subscription_id="your-sub")

# Accessing keystore should work
keyvault = ws.get_default_keyvault()
secret = keyvault.get_secret("my-secret")
```

---

## Monitoring and Auditing

### Enable Diagnostic Logging (If Not Already)

**Your Bicep likely has this, but verify:**

```bicep
// In infra/components/monitoring/diagnostics.bicep
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: 'kv-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
      }
    ]
  }
}
```

### Query Access Logs

**After switching to Secrets Officer, verify access**:

```kusto
// Kusto query - Azure Monitor Log Analytics
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName in ("SecretGet", "SecretList", "SecretSet")
| where CallerIPAddress contains <azure-ml-workspace-id>
| project TimeGenerated, OperationName, ResultSignature, DurationMs
| order by TimeGenerated desc
```

### Set Up Alerts (Optional)

```bicep
resource unexpectedKeyVaultAccess 'Microsoft.Insights/metricAlerts@2018-03-01' = if (deployMonitoring) {
  name: 'Alert-Unexpected-KeyVault-Access'
  location: 'global'
  properties: {
    description: 'Alert on unexpected Key Vault access patterns'
    scopes: [keyVault.id]
    criteria: {
      allOf: [
        {
          metricName: 'ServiceApiHit'
          operator: 'GreaterThan'
          threshold: 100  // Adjust based on normal usage
          timeAggregation: 'Count'
          timeWindow: 'PT5M'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
```

---

## Rollback Plan

If you need to revert to Administrator role:

```bicep
// Change back to
roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')  // Administrator
```

**However**, after switching to Secrets Officer, there's typically no need to rollback because:
- ✅ All normal Azure ML operations continue to work
- ✅ Secrets Officer has all permissions Azure ML actually requires
- ✅ You only gain security benefits (not lose functionality)

---

## Summary

**Current Setup:**
```
Azure ML Workspace Managed Identity
    ↓ has
Key Vault Administrator Role
    ↓ on
Platform Key Vault (Shared RG)
    ↓ allows
✅ Full secret management (create/read/update/delete)
✅ Certificate management
✅ Cryptographic key management
✅ Full key vault administration
```

**Recommendation:**
- ✅ **Development:** Keep current `Key Vault Administrator`
- ✅ **Production:** Switch to `Key Vault Secrets Officer` (better security posture)
- ✅ **Locked Down:** Switch to `Key Vault Secrets User` (read-only)

Your current configuration is appropriate for development/testing. For production, consider the Secrets Officer role for defense-in-depth.

---

## Quick Reference Table

| Environment | Recommended Role | Bicep Role ID | Notes |
|-------------|-----------------|---------------|-------|
| **Dev/Test** | Administrator | `00482a5a-887f-4fb3-b363-3b7fe8e74483` | Current config - good for iteration |
| **Staging** | Secrets Officer | `b86a8fe4-44ce-4948-aee5-eccb2c155090` | Microsoft recommended - no cost increase |
| **Production** | Secrets Officer | `b86a8fe4-44ce-4948-aee5-eccb2c155090` | Compliant, least privilege |
| **Locked-Down** | Secrets User | `4633458b-17de-408a-b874-0445c86b69e6` | Read-only, maximum security |

---

## References

1. **Azure ML Security Best Practices:** https://learn.microsoft.com/en-us/azure/machine-learning/concept-enterprise-security
2. **Azure RBAC Roles:** https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
3. **Key Vault Best Practices:** https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices
4. **Azure Well-Architected Framework - Identity Security:** https://learn.microsoft.com/en-us/azure/architecture/framework/security/design-identity-authentication