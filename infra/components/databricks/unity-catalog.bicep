// Unity Catalog Configuration Module
// NOTE: Due to tenant policy preventing deployment scripts, this module only creates
// the Access Connector (managed identity). Unity Catalog must be configured manually
// via Databricks CLI or REST API after deployment.

param location string
param projectName string
param environmentName string
param tags object
@description('Optional storage account id to grant access for Unity Catalog')
param storageAccountId string = ''

// Variables
var metastoreName = 'metastore-${projectName}-${environmentName}'

// ========== Access Connector (Managed Identity) ==========
// This provides secure authentication to storage without shared keys
module accessConnector 'access-connector.bicep' = {
  name: 'access-connector-${projectName}-${environmentName}'
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
    storageAccountId: storageAccountId
  }
}

// ========== Outputs ==========
output metastoreName string = metastoreName
output accessConnectorId string = accessConnector.outputs.accessConnectorId
// Note: metastoreId will be empty - must create metastore manually
output metastoreId string = ''
