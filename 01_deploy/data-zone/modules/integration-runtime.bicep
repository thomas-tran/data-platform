/**
* Module: Shared integration runtime to allow you rapidly onboard data products
**/

targetScope = 'resourceGroup'

/** Parameters **/

param location string
param prefix string
param tags object
param subnetId string
param adminUsername string = 'VmMainUser'

@secure()
param adminPassword string
param privateDnsZoneIdDataFactory string = ''
param privateDnsZoneIdDataFactoryPortal string = ''
param purviewId string = ''
param purviewSelfHostedIntegrationRuntimeAuthKey string = ''
param deploySelfHostedIntegrationRuntimes bool = false
param datafactoryIds array

// Variables
var datafactoryRuntimes001Name = '${prefix}-runtime-datafactory001'
var shir001Name = '${prefix}-shir001'
var shir002Name = '${prefix}-shir002'


/** Resources **/
module datafactoryRuntimes001 'templates/data-factory-runtime.template.bicep' = {
  name: 'datafactoryRuntimes001'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    subnetId: subnetId
    datafactoryName: datafactoryRuntimes001Name
    privateDnsZoneIdDataFactory: privateDnsZoneIdDataFactory
    privateDnsZoneIdDataFactoryPortal: privateDnsZoneIdDataFactoryPortal
    purviewId: purviewId
  }
}

resource datafactoryRuntimes001IntegrationRuntime001 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: '${datafactoryRuntimes001Name}/shir-${shir001Name}'
  dependsOn: [
    datafactoryRuntimes001
  ]
  properties: {
    type: 'SelfHosted'
    description: 'Self Hosted Integration Runtime running on ${shir001Name}'
  }
}

module datafactoryRuntimes001SelfHostedIntegrationRuntime001 'templates/self-hosted-runtime.template.bicep' = if (deploySelfHostedIntegrationRuntimes) {
  name: 'dfRuntimes001SelfHostedIntegrationRuntime001'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    subnetId: subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    dfIntegrationRuntimeAuthKey: datafactoryRuntimes001IntegrationRuntime001.listAuthKeys().authKey1
    vmName: shir001Name
    vmSkuCapacity: 1
    vmSkuName: 'Standard_DS2_v2'
    vmSkuTier: 'Standard'
  }
}


module shareDatafactoryRuntimes001IntegrationRuntime001 'auxiliary/shareSelfHostedIntegrationRuntime.bicep' = [ for (datafactoryId, i) in datafactoryIds: if (deploySelfHostedIntegrationRuntimes) {
  name: 'shareDatafactoryRuntimes001IntegrationRuntime001-${i}'
  dependsOn: [
    datafactoryRuntimes001SelfHostedIntegrationRuntime001
  ]
  scope: resourceGroup(split(datafactoryId, '/')[2], split(datafactoryId, '/')[4])
  params: {
    datafactorySourceId: datafactoryRuntimes001.outputs.datafactoryId
    datafactorySourceShirId: datafactoryRuntimes001IntegrationRuntime001.id
    datafactoryDestinationId: datafactoryId
  }
}]

module purviewSelfHostedIntegrationRuntime001 'templates/self-hosted-runtime.template.bicep' = if (deploySelfHostedIntegrationRuntimes && purviewSelfHostedIntegrationRuntimeAuthKey != '') {
  name: 'purviewSelfHostedIntegrationRuntime001'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    subnetId: subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    dfIntegrationRuntimeAuthKey: purviewSelfHostedIntegrationRuntimeAuthKey
    vmName: shir002Name
    vmSkuCapacity: 1
    vmSkuName: 'Standard_DS2_v2'
    vmSkuTier: 'Standard'
  }
}
