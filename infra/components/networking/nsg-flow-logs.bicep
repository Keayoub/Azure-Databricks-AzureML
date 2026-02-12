// NSG Flow Logs Module
// Enables Network Security Group flow logs for monitoring and security analysis
// Note: Flow logs must be deployed to NetworkWatcherRG (auto-created by Azure per region)

param location string
param projectName string
param environmentName string
param tags object = {}

// Network parameters
param networkSecurityGroupIds array

// Storage account name for flow logs (must be in same region as NSGs)
param storageAccountName string

// Log Analytics workspace for Traffic Analytics
param logAnalyticsWorkspaceId string

// Enable Traffic Analytics
param enableTrafficAnalytics bool = true

// Flow log retention in days
param retentionDays int = 30

// ========== Deploy Flow Logs via Helper Module ==========
// Flow logs must be deployed to NetworkWatcherRG scope
module flowLogsDeployment 'nsg-flow-logs-helper.bicep' = [for (nsgId, index) in networkSecurityGroupIds: {
  name: '${projectName}-${environmentName}-flowlog-${index}'
  scope: resourceGroup('NetworkWatcherRG')
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
    nsgId: nsgId
    index: index
    storageAccountId: resourceId('Microsoft.Storage/storageAccounts', storageAccountName)
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    enableTrafficAnalytics: enableTrafficAnalytics
    retentionDays: retentionDays
  }
}]

// ========== Outputs ==========
output flowLogIds array = [for (nsgId, index) in networkSecurityGroupIds: flowLogsDeployment[index].outputs.flowLogId]
output flowLogNames array = [for (nsgId, index) in networkSecurityGroupIds: flowLogsDeployment[index].outputs.flowLogName]
output trafficAnalyticsEnabled bool = enableTrafficAnalytics
output retentionPolicyDays int = retentionDays
