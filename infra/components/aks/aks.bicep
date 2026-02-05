// Azure Kubernetes Service (AKS) Cluster Module
// Private AKS cluster with enhanced security
// Based on AKS Secure Baseline Landing Zone Accelerator patterns

param location string
param projectName string
param environmentName string
param aksSubnetId string
param nodeCount int
param vnetId string
param privateEndpointSubnetId string
param tags object

var clusterName = 'aks-${projectName}-${environmentName}'
var logAnalyticsWorkspaceName = 'log-${projectName}-${environmentName}'

// ========== Log Analytics Workspace for AKS ==========
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ========== Azure Kubernetes Service ==========
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    kubernetesVersion: '1.29' // Latest stable version
    enableRBAC: true
    enablePodSecurityPolicy: false // Deprecated - use Pod Security Standards instead
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'cilium'
      dnsServiceIP: '10.1.0.10'
      serviceCidr: '10.1.0.0/16'
      outboundType: 'loadBalancer'
      loadBalancerSku: 'standard'
    }
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: nodeCount
        vmSize: 'Standard_DS3_v2'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        maxCount: 10
        minCount: 1
        enableAutoScaling: true
        enableNodePublicIP: false
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        vnetSubnetID: aksSubnetId
        podSubnetID: aksSubnetId
        nodeTaints: []
      }
      {
        name: 'userpool'
        count: nodeCount
        vmSize: 'Standard_D4s_v3'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        maxCount: 20
        minCount: 0
        enableAutoScaling: true
        enableNodePublicIP: false
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        vnetSubnetID: aksSubnetId
        podSubnetID: aksSubnetId
        nodeTaints: [
          'workload=inference:NoSchedule'
        ]
      }
    ]
    apiServerAccessProfile: {
      enablePrivateCluster: true
      enablePrivateClusterPublicFQDN: false
      privateDNSZone: 'system'
      authorizedIPRanges: []
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
      azurepolicy: {
        enabled: true
        config: {
          version: 'v2'
        }
      }
    }
    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
        securityMonitoring: {
          enabled: true
        }
      }
      imageCleaner: {
        enabled: true
        intervalHours: 24
      }
      workloadIdentity: {
        enabled: true
      }
    }
    httpProxyConfig: {
      httpProxy: null
      httpsProxy: null
      noProxy: []
      trustedCa: null
    }
    storageProfile: {
      blobCSIDriver: {
        enabled: true
      }
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
  }
}

// ========== Outputs ==========
output aksClusterName string = aksCluster.name
output aksClusterResourceId string = aksCluster.id
output fqdn string = aksCluster.properties.fqdn
output privateFqdn string = aksCluster.properties.privateFQDN
