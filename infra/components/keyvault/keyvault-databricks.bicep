// Azure Key Vault for Databricks Secret Scopes
// This Key Vault is dedicated to Databricks-accessible secrets ONLY
// Uses Access Policies (required for Databricks secret scope integration)
// Isolated from platform/infrastructure secrets

param location string
param projectName string
param environmentName string
param privateEndpointSubnetId string = ''
param tags object

var keyVaultName = 'kv-${environmentName}-dbx-${projectName}-${uniqueString(resourceGroup().id, projectName, 'v2')}'
var keyVaultPrivateEndpointName = 'pe-${keyVaultName}-vault'

// Databricks Service Principal IDs by region
// Source: https://learn.microsoft.com/azure/databricks/security/secrets/
var databricksServicePrincipals = {
  canadacentral: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  canadaeast: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  eastus: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  eastus2: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  westus: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  westus2: '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
  // Add more regions as needed - check Microsoft documentation
}

var databricksServicePrincipalId = databricksServicePrincipals[location]

// ========== Databricks-Specific Key Vault ==========
resource databricksKeyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: take(keyVaultName, 24) // Max 24 chars
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    
    // CRITICAL: Must use Access Policies for Databricks secret scope compatibility
    // Azure RBAC is NOT supported for Databricks secret scopes
    // Source: https://learn.microsoft.com/azure/databricks/security/secrets/
    enableRbacAuthorization: false
    
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices' // Required for Databricks service
      ipRules: []
      virtualNetworkRules: []
    }
    
    // Access Policies for Databricks service principal
    // Grants Get and List permissions only (read-only access)
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: databricksServicePrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// ========== Private Endpoint ==========
// Creates private endpoint for Databricks Key Vault if subnet is provided
resource databricksKeyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = if (!empty(privateEndpointSubnetId)) {
  name: keyVaultPrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: keyVaultPrivateEndpointName
        properties: {
          privateLinkServiceId: databricksKeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// ========== Outputs ==========
output keyVaultId string = databricksKeyVault.id
output keyVaultName string = databricksKeyVault.name
output keyVaultUri string = databricksKeyVault.properties.vaultUri
output resourceId string = databricksKeyVault.id
output dnsName string = databricksKeyVault.properties.vaultUri
