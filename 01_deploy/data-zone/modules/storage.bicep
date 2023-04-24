/**
** Module: Data lake storage core module
**/

targetScope = 'resourceGroup'

/** Parameters **/
param prefix string
param location string
param sku string = ''
param tags object
param subnetId string
param purviewId string = ''
param privateDnsZoneIdDfs string = ''
param privateDnsZoneIdBlob string = ''
param subscriptionIds array = []

/** Variables **/
var storageRawZoneName = '${prefix}raw'
var storageEnrichedZoneName = '${prefix}enriched'
var storageCuratedZoneName = '${prefix}curated'
var storageWorkspaceZoneName = '${prefix}workspace'
var rawZoneFileSystemNames = [
  'landing'
  'conformance'
]
var enrichedZoneFileSystemNames = [
  'standardize'
]
var curatedZoneFileSystemNames = [
  'data-product'
]


/** Resources **/
module storageRawZone 'templates/storage.template.bicep' = {
  name: 'storageRaw'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    sku: sku
    subnetId: subnetId
    storageAccountName: storageRawZoneName
    privateDnsZoneIdBlob: privateDnsZoneIdBlob
    privateDnsZoneIdDfs: privateDnsZoneIdDfs
    fileSystemNames: rawZoneFileSystemNames
    purviewId: purviewId
    subscriptionIds: subscriptionIds
  }
}

module storageEnrichedZone 'templates/storage.template.bicep' = {
  name: 'storageEnriched'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    sku: sku
    subnetId: subnetId
    storageAccountName: storageEnrichedZoneName
    privateDnsZoneIdBlob: privateDnsZoneIdBlob
    privateDnsZoneIdDfs: privateDnsZoneIdDfs
    fileSystemNames: enrichedZoneFileSystemNames
    purviewId: purviewId
    subscriptionIds: subscriptionIds
  }
}


module storageCuratedZone 'templates/storage.template.bicep' = {
  name: 'storageCurated'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    sku: sku
    subnetId: subnetId
    storageAccountName: storageCuratedZoneName
    privateDnsZoneIdBlob: privateDnsZoneIdBlob
    privateDnsZoneIdDfs: privateDnsZoneIdDfs
    fileSystemNames: curatedZoneFileSystemNames
    purviewId: purviewId
    subscriptionIds: subscriptionIds
  }
}



module storageWorkspaceZone 'templates/storage.template.bicep' = {
  name: 'storageWorkspace'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    sku: sku
    subnetId: subnetId
    storageAccountName: storageWorkspaceZoneName
    privateDnsZoneIdBlob: privateDnsZoneIdBlob
    privateDnsZoneIdDfs: privateDnsZoneIdDfs
    fileSystemNames: curatedZoneFileSystemNames
    purviewId: purviewId
    subscriptionIds: subscriptionIds
  }
}

/** Outputs **/
output storageRawZoneId string = storageRawZone.outputs.storageId
output storageRawZoneFileSystemId string = storageRawZone.outputs.storageFileSystemIds[0].storageFileSystemId
output storageEnrichedZoneId string = storageEnrichedZone.outputs.storageId
output storageEnrichedZoneFileSystemId string = storageEnrichedZone.outputs.storageFileSystemIds[0].storageFileSystemId
output storageCuratedZoneId string = storageCuratedZone.outputs.storageId
output storageCuratedZoneFileSystemId string = storageCuratedZone.outputs.storageFileSystemIds[0].storageFileSystemId
output storageWorkspaceZoneId string = storageWorkspaceZone.outputs.storageId
output storageWorkspaceZoneFileSystemId string = storageWorkspaceZone.outputs.storageFileSystemIds[0].storageFileSystemId
