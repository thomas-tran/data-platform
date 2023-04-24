/**
* Template: Data factory shared integration runtime use to provide data integration capabilities
*           acrosss diferrent network environments
**/

targetScope = 'resourceGroup'


/** Parameters **/
param location string
param tags object
param subnetId string
param datafactoryName string
param privateDnsZoneIdDataFactory string = ''
param privateDnsZoneIdDataFactoryPortal string = ''
param purviewId string = ''

/** Variables **/
// consider to use AutoresolveIntegrationRuntime as it
// may impact on performance and could not reuse the existing cluster 
var defaultManagedVNetRuntimeName = 'AutoResolveIntegrationRuntime'
var privateEndpointNameDatafactory = '${datafactory.name}-datafactory-private-endpoint'
var privateEndpointNamePortal = '${datafactory.name}-portal-private-endpoint'

/** Resources **/
resource datafactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: datafactoryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    globalParameters: {}
    publicNetworkAccess: 'Disabled'
    purviewConfiguration: {
      purviewResourceId: purviewId
    }
  }
}

resource privateEndpointDatafactory 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: privateEndpointNameDatafactory
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: privateEndpointNameDatafactory
        properties: {
          groupIds: [
            'dataFactory'
          ]
          privateLinkServiceId: datafactory.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource privateEndpointDatafactoryARecord 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = if (!empty(privateDnsZoneIdDataFactory)) {
  parent: privateEndpointDatafactory
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${privateEndpointDatafactory.name}-arecord'
        properties: {
          privateDnsZoneId: privateDnsZoneIdDataFactory
        }
      }
    ]
  }
}

resource privateEndpointPortal 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: privateEndpointNamePortal
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: privateEndpointNamePortal
        properties: {
          groupIds: [
            'portal'
          ]
          privateLinkServiceId: datafactory.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}


resource privateEndpointPortalARecord 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = if (!empty(privateDnsZoneIdDataFactoryPortal)) {
  parent: privateEndpointPortal
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${privateEndpointPortal.name}-arecord'
        properties: {
          privateDnsZoneId: privateDnsZoneIdDataFactoryPortal
        }
      }
    ]
  }
}

resource datafactoryManagedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  parent: datafactory
  name: 'default'
  properties: {}
}

resource datafactoryManagedIntegrationRuntime001 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  parent: datafactory
  name: defaultManagedVNetRuntimeName
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      type: 'ManagedVirtualNetworkReference'
      referenceName: datafactoryManagedVirtualNetwork.name
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

/** Outputs **/
output datafactoryId string = datafactory.id
