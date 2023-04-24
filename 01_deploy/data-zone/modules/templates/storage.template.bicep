/**
* Template: Data lake storage
**/

targetScope = 'resourceGroup'

/** Parameters **/

param location string
param tags object
param subnetId string
param fileSystemNames array
param storageAccountName string
param sku string
param purviewId string = ''
param subscriptionIds array = []
param privateDnsZoneIdDfs string = ''
param privateDnsZoneIdBlob string = ''

/** Variables **/

// Storage name only allow 3-24 characters and container numbers and lowercase letters
// the formattedStorageAccount converts input name to lowercase and remove character - or _
var formattedStorageAccount = toLower(replace(replace(storageAccountName, '-', ''), '_', ''))

// If sku is not provide, use the Standard_LRS
var skuName = empty(sku) ? 'Standard_LRS' : sku

// Enable private endpoint name for Blob service
var storagePrivateEndpointNameBlob = '${storageAccount.name}-blob-private-endpoint'

// Enable private endpoint name for distributed file system namespaces
var storagePrivateEndpointNameDfs = '${storageAccount.name}-dfs-private-endpoint'

// Synapse resource access rules
var synapseResourceAccessrules = [for subscriptionId in union(subscriptionIds, array(subscription().subscriptionId)): {
  tenantId: subscription().tenantId
  resourceId: '/subscriptions/${subscriptionId}/resourceGroups/*/providers/Microsoft.Synapse/workspaces/*'
}]

// Purview resource access rules
var purviewResourceAccessRules = {
  tenantId: subscription().tenantId
  resourceId: purviewId
}
var resourceAccessRules = empty(purviewId) ? synapseResourceAccessrules : union(synapseResourceAccessrules, array(purviewResourceAccessRules))

/** Resources **/
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: formattedStorageAccount
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Service'
        }
        table: {
          enabled: true
          keyType: 'Service'
        }
      }
    }
    isHnsEnabled: true
    isNfsV3Enabled: false
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'Metrics'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
      resourceAccessRules: resourceAccessRules
    }
    supportsHttpsTrafficOnly: true
  }
}

// lifecycle management policy for the storage
resource storageManagementPolicies 'Microsoft.Storage/storageAccounts/managementPolicies@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'default'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 90
                }
              }
              snapshot: {
                tierToCool: {
                  daysAfterCreationGreaterThan: 90
                }
              }
              version: {
                tierToCool: {
                  daysAfterCreationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: []
            }
          }
        }
      ]
    }
  }
}

// Blob Service retention policy
resource storageBlobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    }
  }
}

// HNS
resource storageFileSystems 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for fsn in fileSystemNames: {
  parent: storageBlobServices
  name: fsn
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}]

// Private endpoint blob
resource storagePrivateEndpointBlob 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: storagePrivateEndpointNameBlob
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: storagePrivateEndpointNameBlob
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: storageAccount.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

// Private endpoint dns zone
resource storagePrivateEndpointBlobARecord 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = if (!empty(privateDnsZoneIdBlob)) {
  parent: storagePrivateEndpointBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${storagePrivateEndpointBlob.name}-arecord'
        properties: {
          privateDnsZoneId: privateDnsZoneIdBlob
        }
      }
    ]
  }
}

// Private endpoint distributed file system 
resource storagePrivateEndpointDfs 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: storagePrivateEndpointNameDfs
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: storagePrivateEndpointNameDfs
        properties: {
          groupIds: [
            'dfs'
          ]
          privateLinkServiceId: storageAccount.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

// Private endpoint distributed file system dns zone
resource storagePrivateEndpointDfsARecord 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = if (!empty(privateDnsZoneIdDfs)) {
  parent: storagePrivateEndpointDfs
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${storagePrivateEndpointDfs.name}-arecord'
        properties: {
          privateDnsZoneId: privateDnsZoneIdDfs
        }
      }
    ]
  }
}


/** Outputs **/
output storageId string = storageAccount.id
output storageFileSystemIds array = [for fsn in fileSystemNames: {
  stgFSId: resourceId('Microsoft.Storage/storageAccounts/blobServices/containers', formattedStorageAccount, 'default', fsn)
}]
