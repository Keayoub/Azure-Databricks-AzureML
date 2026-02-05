// Azure Key Vault Module with Security Features
// This Key Vault is used for:
// - Storing secrets for Azure ML
// - Databricks secret management
// - AI Foundry credentials

param location string
param projectName string
param environmentName string
param adminObjectId string = ''
param vnetId string
param privateEndpointSubnetId string
param tags object

var keyVaultName = 'kv-${projectName}-${environmentName}-${uniqueString(resourceGroup().id)}'
var privateEndpointName = 'pe-${keyVaultName}'

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

// ========== Private DNS Zone ==========
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'kv-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Private Endpoint ==========
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'vault-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ========== Outputs ==========
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
