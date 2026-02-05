// Azure API Management Module
// This module deploys API Management with:
// - Internal VNet integration
// - Private DNS zones for all APIM endpoints
// - Application Insights integration
// - System-assigned managed identity
// - Developer/Standard SKU for VNet support

param location string
param projectName string
param environmentName string
param vnetId string
param apimSubnetId string
param appInsightsId string
param appInsightsInstrumentationKey string
param publisherEmail string = 'admin@example.com'
param publisherName string = 'API Management Admin'
param sku string = 'Developer'  // Developer, Basic, Standard, Premium
param tags object

var apimName = 'apim-${projectName}-${environmentName}'

// Private DNS zones for APIM (internal mode requires all 4)
var apimDnsZones = [
  'privatelink.azure-api.net'
  'privatelink.portal.azure-api.net'
  'privatelink.developer.azure-api.net'
  'privatelink.management.azure-api.net'
]

// ========== API Management Service ==========
resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'Internal'  // Internal VNet integration
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
    }
    publicNetworkAccess: 'Disabled'
  }
}

// ========== Application Insights Integration ==========
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  parent: apimService
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    resourceId: appInsightsId
  }
}

resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-05-01-preview' = {
  parent: apimService
  name: 'applicationinsights'
  properties: {
    loggerId: apimLogger.id
    alwaysLog: 'allErrors'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

// ========== Private DNS Zones ==========
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in apimDnsZones: {
  name: zone
  location: 'global'
  tags: tags
}]

resource privateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in apimDnsZones: {
  parent: privateDnsZones[i]
  name: '${apimName}-link-${i}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

// Note: APIM with Internal VNet mode automatically creates private IPs
// No separate private endpoint needed - the service itself is internal

// ========== Outputs ==========
output apimName string = apimService.name
output apimId string = apimService.id
output apimGatewayUrl string = apimService.properties.gatewayUrl
output apimPortalUrl string = apimService.properties.portalUrl
output apimPrincipalId string = apimService.identity.principalId
output apimPrivateIpAddresses array = apimService.properties.privateIPAddresses
