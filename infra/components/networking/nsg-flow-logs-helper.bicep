// NSG Flow Logs Helper Module
// Deployed to NetworkWatcherRG scope to create flow logs

param location string
param projectName string
param environmentName string
param tags object = {}
param nsgId string
param index int
param storageAccountId string
param logAnalyticsWorkspaceId string
param enableTrafficAnalytics bool
param retentionDays int

// Reference Network Watcher in NetworkWatcherRG
resource networkWatcher 'Microsoft.Network/networkWatchers@2023-11-01' existing = {
  name: 'NetworkWatcher_${location}'
}

// Create flow log
resource flowLog 'Microsoft.Network/networkWatchers/flowLogs@2023-11-01' = {
  name: '${projectName}-${environmentName}-flowlog-${index}'
  parent: networkWatcher
  location: location
  tags: tags
  properties: {
    targetResourceId: nsgId
    storageId: storageAccountId
    enabled: true
    retentionPolicy: {
      days: retentionDays
      enabled: true
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: enableTrafficAnalytics ? {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceResourceId: logAnalyticsWorkspaceId
        trafficAnalyticsInterval: 10
      }
    } : null
  }
}

output flowLogId string = flowLog.id
output flowLogName string = flowLog.name
