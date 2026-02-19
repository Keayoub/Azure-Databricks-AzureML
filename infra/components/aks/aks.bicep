// Azure Kubernetes Service (AKS) Cluster Module
// Private AKS cluster with enhanced security
// Based on AKS Secure Baseline Landing Zone Accelerator patterns

param location string
param projectName string
param environmentName string
param aksSubnetId string
param nodeCount int
param tags object

var clusterName = 'aks-${projectName}-${environmentName}'

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
    kubernetesVersion: '1.32.0' // Using 1.32.0 which supports both KubernetesOfficial and LTS plans
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
        vmSize: 'Standard_D2s_v3'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        maxCount: 10
        minCount: 1
        enableAutoScaling: true
        enableNodePublicIP: false
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        vnetSubnetID: aksSubnetId
        nodeTaints: []
      }
      {
        name: 'userpool'
        count: nodeCount
        vmSize: 'Standard_D4s_v5'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        maxCount: 20
        minCount: 0
        enableAutoScaling: true
        enableNodePublicIP: false
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        vnetSubnetID: aksSubnetId
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
        enabled: false
      }
      azurepolicy: {
        enabled: true
        config: {
          version: 'v2'
        }
      }
    }
    securityProfile: {
      imageCleaner: {
        enabled: true
        intervalHours: 24
      }
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
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
output privateFqdn string = aksCluster.properties.privateFQDN
