/**
* Template: External data ingres storage
**/

targetScope = 'resourceGroup'

/** Parameters **/

param location string
param tags object
param subnetId string
param storageAccountName string
param privateDnsZoneIdBlob string = ''
param purviewId string = ''
param subscriptionIds array = []
param fileSystemNames array
param sku string

/** Variables **/

// Storage name only allow 3-24 characters and container numbers and lowercase letters
// the formattedStorageAccount converts input name to lowercase and remove character - or _
var formattedStorageAccount = toLower(replace(replace(storageAccountName, '-', ''), '_', ''))

// Enable private endpoint name for external storage blob service
var externalStoragePrivateEndpointNameBlob = '${externalStorageAccount.name}-blob-private-endpoint'

var synapseResourceAccessrules = [for subscriptionId in union(subscriptionIds, array(subscription().subscriptionId)): {
  tenantId: subscription().tenantId
  resourceId: '/subscriptions/${subscriptionId}/resourceGroups/*/providers/Microsoft.Synapse/workspaces/*'
}]
var purviewResourceAccessRules = {
  tenantId: subscription().tenantId
  resourceId: purviewId
}
var resourceAccessRules = empty(purviewId) ? synapseResourceAccessrules : union(synapseResourceAccessrules, array(purviewResourceAccessRules))

// If sku is not provide, use the Standard_LRS
var skuName = empty(sku) ? 'Standard_LRS' : sku

/** Resources **/

resource externalStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
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
    isHnsEnabled: false
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

// lifecyle management policies
resource externalStorageManagementPolicies 'Microsoft.Storage/storageAccounts/managementPolicies@2022-09-01' = {
  parent: externalStorageAccount
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
                tierToArchive: {
                  daysAfterLastAccessTimeGreaterThan: 365
                  daysAfterModificationGreaterThan: 365
                }
                delete: {
                  daysAfterLastAccessTimeGreaterThan: 730
                  daysAfterModificationGreaterThan: 730
                }
              }
              snapshot: {
                tierToCool: {
                  daysAfterCreationGreaterThan: 90
                }
                delete: {
                  daysAfterCreationGreaterThan: 730
                }
              }
              version: {
                tierToCool: {
                  daysAfterCreationGreaterThan: 90
                }
                tierToArchive: {
                  daysAfterCreationGreaterThan: 365
                }
                delete: {
                  daysAfterCreationGreaterThan: 730
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

// retention policy
resource externalStorageBlobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: externalStorageAccount
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

// blob services
resource storageExternalFileSystems 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for fsn in fileSystemNames: {
  parent: externalStorageBlobServices
  name: fsn
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}]

// private endpoint of blob service
resource externalStoragePrivateEndpointBlob 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: externalStoragePrivateEndpointNameBlob
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: externalStoragePrivateEndpointNameBlob
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: externalStorageAccount.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

// private endpoint dns zone
resource externalStoragePrivateEndpointBlobARecord 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = if (!empty(privateDnsZoneIdBlob)) {
  parent: externalStoragePrivateEndpointBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${externalStoragePrivateEndpointBlob.name}-arecord'
        properties: {
          privateDnsZoneId: privateDnsZoneIdBlob
        }
      }
    ]
  }
}

/** Outputs **/
