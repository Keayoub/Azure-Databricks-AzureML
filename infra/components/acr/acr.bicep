// Azure Container Registry Module with Security Features
// This ACR is used for:
// - Azure ML container images
// - AI Foundry model containers
// - AKS deployments

param location string
param projectName string
param environmentName string
param vnetId string
param privateEndpointSubnetId string
param tags object

var acrName = 'acr${replace(projectName, '-', '')}${environmentName}${uniqueString(resourceGroup().id)}'
var privateEndpointName = 'pe-${acrName}'

// ========== Azure Container Registry ==========
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: take(acrName, 50) // Max 50 chars, alphanumeric only
  location: location
  tags: tags
  sku: {
    name: 'Premium' // Premium required for private endpoints
  }
  properties: {
    adminUserEnabled: false // Disable admin user - use Entra ID
    anonymousPullEnabled: false // Disable anonymous pull
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    encryption: {
      status: 'disabled' // Can be enabled with customer-managed keys
    }
    dataEndpointEnabled: true
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'enabled'
      }
      retentionPolicy: {
        days: 30
        status: 'enabled'
      }
      softDeletePolicy: {
        status: 'disabled'
      }
    }
  }
}

// ========== Private DNS Zone ==========
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'acr-dns-link'
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
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'registry-dns-zone-group'
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
output acrId string = containerRegistry.id
output acrName string = containerRegistry.name
output acrLoginServer string = containerRegistry.properties.loginServer
