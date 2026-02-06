// Jumpbox (Management VM) Module
// Secure Windows VM for accessing Azure resources via Bastion
// No public IP - accessible only through Azure Bastion

param location string
param projectName string
param environmentName string
param subnetId string
param adminUsername string = 'azureadmin'
@secure()
param adminPassword string
param tags object

@description('VM size for jumpbox')
param vmSize string = 'Standard_D2s_v3'

@description('Windows Server version')
@allowed(['2019-Datacenter', '2022-Datacenter', '2022-datacenter-azure-edition'])
param windowsOSVersion string = '2022-datacenter-azure-edition'

var vmName = 'vm-jumpbox-${environmentName}-${projectName}'
var nicName = 'nic-${vmName}'
var osDiskName = '${vmName}-osdisk'

// ========== Network Interface ==========
resource nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

// ========== Virtual Machine ==========
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 128
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// ========== VM Extensions ==========

// Install Azure Monitor Agent
resource azureMonitorAgent 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: vm
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// Install common tools via custom script
resource customScript 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: vm
  name: 'InstallTools'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "& { Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString(\'https://chocolatey.org/install.ps1\')); choco install -y azure-cli azcopy vscode git; Install-PackageProvider -Name NuGet -Force; Install-Module -Name Az -Force -AllowClobber; }"'
    }
  }
  dependsOn: [
    azureMonitorAgent
  ]
}

// ========== Outputs ==========
output vmId string = vm.id
output vmName string = vm.name
output privateIPAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output nicId string = nic.id
