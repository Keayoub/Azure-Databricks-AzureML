// Diagnostic settings for Azure Databricks workspace
// Sends logs and metrics to Log Analytics

param databricksWorkspaceId string
param logAnalyticsWorkspaceId string
param nameSuffix string = 'diag'
param enableLogs bool = true
param enableMetrics bool = true
param logCategoryGroups array = [
  'allLogs'
]
param metricCategories array = [
  'AllMetrics'
]

resource databricksWorkspace 'Microsoft.Databricks/workspaces@2024-05-01' existing = {
  id: databricksWorkspaceId
}

resource databricksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${databricksWorkspace.name}-${nameSuffix}'
  scope: databricksWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: enableLogs ? [
      for group in logCategoryGroups: {
        categoryGroup: group
        enabled: true
      }
    ] : []
    metrics: enableMetrics ? [
      for category in metricCategories: {
        category: category
        enabled: true
      }
    ] : []
  }
}

output diagnosticSettingsId string = databricksDiagnostics.id
