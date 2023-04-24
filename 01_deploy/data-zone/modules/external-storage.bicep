/**
* Module: External data storage module for 3rd parties publishers to land data
**/

targetScope = 'resourceGroup'

/** Parameters **/

param location string
param prefix string
param tags object
param subnetId string
param purviewId string = ''
param privateDnsZoneIdBlob string = ''
param subscriptionIds array = []
param sku string

/** Variables **/

var externalStorageDefaultName = '${prefix}defaultExt001'
var fileSystemNames = [
  'data'
]

/** Resources **/

module externalStorage001 'templates/external-storage.template.bicep' = {
  name: 'externalStorage001'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    subnetId: subnetId
    storageAccountName: externalStorageDefaultName
    privateDnsZoneIdBlob: privateDnsZoneIdBlob
    fileSystemNames: fileSystemNames
    purviewId: purviewId
    sku: sku
    subscriptionIds: subscriptionIds
  }
}
