// Azure Container Apps Module
// Deploys Azure Container Apps Environment with internal networking
// Based on Azure Container Apps Landing Zone Accelerator patterns

param location string
param projectName string
param environmentName string
param tags object
param vnetId string
param infrastructureSubnetId string
param logAnalyticsWorkspaceId string

@secure()
param appInsightsInstrumentationKey string = ''

var acaEnvironmentName = 'cae-${projectName}-${environmentName}'
var infrastructureResourceGroupName = 'ME_${resourceGroup().name}_${acaEnvironmentName}'
var containerAppsDomain = '${acaEnvironmentName}.${location}.azurecontainerapps.io'

// ========== Azure Container Apps Environment ==========
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: acaEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2022-10-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2022-10-01').primarySharedKey
      }
    }
    zoneRedundant: false // Set to true for production workloads
    vnetConfiguration: {
      internal: true // Internal environment (private)
      infrastructureSubnetId: infrastructureSubnetId
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    infrastructureResourceGroup: infrastructureResourceGroupName
    daprAIInstrumentationKey: appInsightsInstrumentationKey
  }
}

// ========== Private DNS Zone for Container Apps ==========
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: containerAppsDomain
  location: 'global'
  tags: tags
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'aca-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ========== Outputs ==========
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output staticIp string = containerAppsEnvironment.properties.staticIp
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output privateDnsZoneId string = privateDnsZone.id
