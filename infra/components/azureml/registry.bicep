// Azure ML Registry Module
// Deploys Microsoft.MachineLearningServices/registries with a minimal, supported schema.

param location string
param environmentName string
param projectName string

@description('Optional explicit registry name. Leave empty to auto-generate.')
@maxLength(33)
param registryName string = ''

@description('Registry public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Additional replication regions. Primary location is always included.')
param replicationRegions array = []

@description('Registry identity mode')
@allowed([
  'SystemAssigned'
  'None'
])
param identityMode string = 'SystemAssigned'

@description('Registry SKU name')
param skuName string = 'Basic'

@description('Optional managed resource group resource ID for the registry. Leave empty to let the service manage this value.')
param managedResourceGroupResourceId string = ''

param tags object = {}

var autoRegistryName = 'amlr-${environmentName}-${projectName}'
var effectiveRegistryName = empty(registryName) ? autoRegistryName : registryName
var effectiveReplicationRegions = union([
  location
], replicationRegions)
var effectiveRegionDetails = [for region in effectiveReplicationRegions: {
  location: region
}]
var baseProperties = {
  publicNetworkAccess: publicNetworkAccess
  regionDetails: effectiveRegionDetails
}
var registryProperties = empty(managedResourceGroupResourceId)
  ? baseProperties
  : union(baseProperties, {
      managedResourceGroup: {
        resourceId: managedResourceGroupResourceId
      }
    })

resource registry 'Microsoft.MachineLearningServices/registries@2025-12-01' = {
  name: effectiveRegistryName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  identity: {
    type: identityMode
  }
  properties: registryProperties
}

output registryName string = registry.name
output registryId string = registry.id
output registryPrincipalId string = identityMode == 'SystemAssigned' ? registry.identity.principalId : ''
output managedResourceGroupId string = contains(registry.properties, 'managedResourceGroup') ? registry.properties.managedResourceGroup.resourceId : ''
