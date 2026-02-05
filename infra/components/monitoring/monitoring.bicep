// Monitoring Module - Application Insights and Log Analytics
// Based on AI Landing Zones patterns
// Provides observability for all resources with diagnostic settings

param location string
param projectName string
param environmentName string
param tags object

// Optional parameters for multi-service monitoring
param enableApplicationInsights bool = true
param enableLogAnalytics bool = true
param logRetentionInDays int = 30

var workspaceName = 'law-${projectName}-${environmentName}'
var appInsightsName = 'ai-${projectName}-${environmentName}'

// ========== Log Analytics Workspace ==========
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (enableLogAnalytics) {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018' // Pay-as-you-go pricing
    }
    retentionInDays: logRetentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ========== Application Insights ==========
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (enableApplicationInsights) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: logRetentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: enableLogAnalytics ? logAnalyticsWorkspace.id : null
  }
}

// ========== Diagnostic Settings for Storage Account ==========
// Call this module to enable diagnostics for storage accounts
// Example: diagnosticSettings('st${projectName}', storageAccountId, ['Blob', 'Queue', 'Table', 'File'])

// ========== Outputs ==========
output logAnalyticsWorkspaceId string = enableLogAnalytics ? logAnalyticsWorkspace.id : ''
output logAnalyticsWorkspaceName string = enableLogAnalytics ? logAnalyticsWorkspace.name : ''
output applicationInsightsId string = enableApplicationInsights ? applicationInsights.id : ''
output applicationInsightsInstrumentationKey string = enableApplicationInsights ? applicationInsights!.properties.InstrumentationKey : ''
output applicationInsightsConnectionString string = enableApplicationInsights ? applicationInsights!.properties.ConnectionString : ''
