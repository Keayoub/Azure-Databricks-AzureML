// Azure Key Vault Module with Security Features (Platform Vault - RBAC)
// This Key Vault is used for:
// - Storing secrets for Azure ML
// - AI Foundry credentials
// - Platform/infrastructure secrets
// - Uses RBAC for access control (NOT for Databricks secret scopes)
// 
// Note: Databricks secret scopes require a separate vault with Access Policies
// See: infra/components/keyvault/keyvault-databricks.bicep

param location string
param projectName string
param environmentName string
param adminObjectId string = ''
param tags object

var keyVaultName = 'kv-${environmentName}-${projectName}-${uniqueString(resourceGroup().id, projectName, 'v2')}'

// ========== Key Vault ==========
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: take(keyVaultName, 24) // Max 24 chars
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // Use RBAC instead of access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true // Cannot be disabled once enabled
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// Assign Key Vault Administrator role to admin (only if adminObjectId is provided)
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(adminObjectId)) {
  scope: keyVault
  name: guid(keyVault.id, adminObjectId, 'KeyVaultAdministrator')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: adminObjectId
    principalType: 'User'
  }
}

// ========== Outputs ==========
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
