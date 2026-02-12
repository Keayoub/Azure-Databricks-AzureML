// Monitoring alerts for Azure Databricks workspace
// Creates an action group and activity log alerts

param location string
param projectName string
param environmentName string
param tags object
param alertEmailAddress string
param databricksWorkspaceId string

var actionGroupName = 'ag-${environmentName}-${projectName}-ops'
var actionGroupShortName = take(replace('${projectName}${environmentName}', '-', ''), 12)

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: 'primary'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

resource databricksAdminFailures 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'ala-${environmentName}-${projectName}-dbx-admin-fail'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    scopes: [
      databricksWorkspaceId
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'status'
          equals: 'Failed'
        }
        {
          field: 'resourceType'
          equals: 'Microsoft.Databricks/workspaces'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

resource databricksResourceHealth 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'ala-${environmentName}-${projectName}-dbx-health'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    scopes: [
      databricksWorkspaceId
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ResourceHealth'
        }
        {
          field: 'resourceType'
          equals: 'Microsoft.Databricks/workspaces'
        }
        {
          field: 'properties.currentHealthStatus'
          containsAny: [
            'Unavailable'
            'Degraded'
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

output actionGroupId string = actionGroup.id
