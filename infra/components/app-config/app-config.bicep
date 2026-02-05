// Azure App Configuration Module
// This module deploys Azure App Configuration with:
// - Private endpoint connectivity
// - Private DNS zone integration
// - System-assigned managed identity
// - Support for feature flags and key-value configuration

param location string
param projectName string
param environmentName string
param vnetId string
param privateEndpointSubnetId string
param tags object

var appConfigName = 'appconfig-${projectName}-${environmentName}'
var privateEndpointName = 'pe-appconfig-${projectName}-${environmentName}'
var privateDnsZoneName = 'privatelink.azconfig.io'

// ========== App Configuration Store ==========
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: appConfigName
  location: location
  tags: tags
  sku: {
    name: 'standard'  // Standard tier supports private endpoints
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: false  // Allow access keys for initial setup, can disable later
    enablePurgeProtection: false  // Set to true for production
    softDeleteRetentionInDays: 7
  }
}

// ========== Private DNS Zone ==========
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${appConfigName}-link'
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
          privateLinkServiceId: appConfig.id
          groupIds: [
            'configurationStores'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'appconfig-dns-zone-group'
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
output appConfigName string = appConfig.name
output appConfigId string = appConfig.id
output appConfigEndpoint string = appConfig.properties.endpoint
output appConfigPrincipalId string = appConfig.identity.principalId
