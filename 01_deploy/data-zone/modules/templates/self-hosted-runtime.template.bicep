/**
* Template: Self-hosted integration run time using virtual machine scale sets
* https://learn.microsoft.com/en-us/azure/data-factory/create-self-hosted-integration-runtime?tabs=data-factory
**/

targetScope = 'resourceGroup'

/** Parameters **/
param location string
param tags object
param subnetId string
param vmName string
param vmSkuName string = 'Standard_DS2_v2'
param vmSkuTier string = 'Standard'
param vmSkuCapacity int = 1
param adminUsername string = 'vmMainUser'
@secure()
param adminPassword string
@secure()
param dfIntegrationRuntimeAuthKey string

/** Variables **/

var lbName = '${vmName}-lb'

/** Resources **/

// create load balancer
resource loadbalancer001 'Microsoft.Network/loadBalancers@2022-09-01' = {
  name: lbName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    backendAddressPools: [
      {
        name: '${vmName}-backendaddresspool'
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendipconfiguration'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    inboundNatPools: [
      {
        name: '${vmName}-natpool'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendipconfiguration')
          }
          protocol: 'Tcp'
          frontendPortRangeStart: 50000
          frontendPortRangeEnd: 50099
          backendPort: 3389
          idleTimeoutInMinutes: 4
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'proberule'
        properties: {
          loadDistribution: 'Default'
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, '${vmName}-backendaddresspool')
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontendipconfiguration')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, '${vmName}-probe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
        }
      }
    ]
    probes: [
      {
        name: '${vmName}-probe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource vm001 'Microsoft.Compute/virtualMachineScaleSets@2022-11-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: vmSkuName
    tier: vmSkuTier
    capacity: vmSkuCapacity
  }
  properties: {
    additionalCapabilities: {}
    automaticRepairsPolicy: {}
    doNotRunExtensionsOnOverprovisionedVMs: true
    overprovision: true
    platformFaultDomainCount: 1
    scaleInPolicy: {
      rules: [
        'Default'
      ]
    }
    singlePlacementGroup: true
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      priority: 'Regular'
      osProfile: {
        adminUsername: adminUsername
        adminPassword: adminPassword
        computerNamePrefix: take(vmName, 9)
        customData: loadFileAsBase64('../../scripts/installSHIRGateway.ps1')
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${vmName}-nic'
            properties: {
              primary: true
              dnsSettings: {}
              enableAcceleratedNetworking: false
              enableFpga: false
              enableIPForwarding: false
              ipConfigurations: [
                {
                  name: '${vmName}-ipconfig'
                  properties: {
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, '${vmName}-backendaddresspool')
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', lbName, '${vmName}-natpool')
                      }
                    ]
                    primary: true
                    privateIPAddressVersion: 'IPv4'
                    subnet: {
                      id: subnetId
                    }
                  }
                }
              ]
            }
          }
        ]
      }
      storageProfile: {
        imageReference: {
          offer: 'WindowsServer'
          publisher: 'MicrosoftWindowsServer'
          sku: '2022-datacenter-azure-edition'
          version: 'latest'
        }
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
        }
      }
      extensionProfile: {
        extensions: [
          {
            name: '${vmName}-integrationruntime-shir'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              typeHandlerVersion: '1.10'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: []
              }
              protectedSettings: {
                commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -NoProfile -NonInteractive -command "cp c:/azuredata/customdata.bin c:/azuredata/installSHIRGateway.ps1; c:/azuredata/installSHIRGateway.ps1 -gatewayKey "${dfIntegrationRuntimeAuthKey}"'
              }
            }
          }
        ]
      }
    }
  }
}
