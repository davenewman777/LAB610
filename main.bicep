metadata name = 'Multi-Region Scenario'
metadata description = 'This bicep code deploys application infrastructure for scenario three, a web-based PaaS application with a database backend for multi-region configuration.'
targetScope = 'subscription'

@allowed([
  'eastus'
  'eastus2'
  'southcentralus'
  'westus2'
  'westus3'
  'centralus'
  'mexicocentral'
  'brazilsouth'
  'canadacentral'
  'australiaeast'
  'southeastasia'
  'centralindia'
  'eastasia'
  'japaneast'
  'koreacentral'
  'southafricanorth'
  'northeurope'
  'swedencentral'
  'uksouth'
  'westeurope'
  'francecentral'
  'germanywestcentral'
  'italynorth'
  'norwayeast'
  'polandcentral'
  'spaincentral'
  'switzerlandnorth'
  'uaenorth'
  'israelcentral'
  'qatarcentral'
])
@description('The Azure region you wish to deploy to. It must support availability zones.')
param primaryRegion string = 'australiaeast'

@description('The Azure region you wish to deploy to. It must support availability zones.')
param secondaryRegion string = 'canadacentral'

@secure()
param sqlpassword string

param zoneredundant bool = true

var rgName = 'tech-connect-lab610-rg'
/* var vnet1Name = 's3-vnet1-${uniqueString(subscription().id)}'
var vnet2Name = 's3-vnet2-${uniqueString(subscription().id)}' */
var sqlServerName = 'tc-sql-${uniqueString(subscription().id)}'
var serverFarmConfig = [
  {
    name: 'tc-asp-pri-${uniqueString(subscription().id)}'
    location: primaryRegion
  }
  {
    name: 'tc-asp-sec-${uniqueString(subscription().id)}'
    location: secondaryRegion
  }
]
var apiAppConfig = [
  {
    name: 'tc-api-pri-${uniqueString(subscription().id)}'
    kind: 'app'
    location: primaryRegion
  }
  {
    name: 'tc-api-sec-${uniqueString(subscription().id)}'
    kind: 'app'
    location: secondaryRegion
  }
]
var feAppConfig = [
  {
    name: 'tc-web-pri-${uniqueString(subscription().id)}'
    kind: 'app'
    location: primaryRegion
  }
  {
    name: 'tc-web-sec-${uniqueString(subscription().id)}'
    kind: 'app'
    location: secondaryRegion
  }

]
/* var vnetAddressPrefix = [
  '192.168.0.0/16'
]

var vnetAddressPrefix2 = [
  '10.1.0.0/16'  // Unique address space for location2
]

var subnetSpec = [
  {
    addressPrefix: '192.168.1.0/25'
    name: 'webSubnet'
  }
  {
    addressPrefix: '192.168.0.0/24'
    name: 'dataSubnet'
  }
]

var subnetSpec2 = [
  {
    addressPrefix: '10.1.1.0/25'
    name: 'webSubnet'
  }
  {
    addressPrefix: '10.1.0.0/24'
    name: 'dataSubnet'
  }
] */

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: primaryRegion
}

/* module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'vnetDeployment1'
  scope: resourceGroup
  params: {
    name: vnet1Name
    addressPrefixes: vnetAddressPrefix
    subnets: [
      for subnet in subnetSpec: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
      }
    ]
  }
}

module virtualNetwork2 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'vnetDeployment2'
  scope: resourceGroup
  params: {
    name: vnet2Name
    addressPrefixes: vnetAddressPrefix2
    subnets: [
      for subnet in subnetSpec2: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
      }
    ]
  }
} */

module serverFarm 'br/public:avm/res/web/serverfarm:0.1.1' = [for farm in serverFarmConfig: {
  name: 'webASPDeploy-${farm.name}'
  scope: resourceGroup
  params: {
    name: farm.name
    location: farm.location
    sku: {
      capacity: 3
      family: 'Pv3'
      name: 'P1v3'
      size: 'P1v3'
      tier: 'PremiumV3'
    }
    zoneRedundant: zoneredundant
    kind: 'Windows'
  }
}]

module apiAppServices 'br/public:avm/res/web/site:0.13.1' = [for (app, i) in apiAppConfig: {
  name: 'appDeploy-${app.name}'
  scope: resourceGroup
  params: {
    kind: app.kind
    location: app.location
    name: app.name
    serverFarmResourceId: app.location == primaryRegion ? serverFarm[0].outputs.resourceId : serverFarm[1].outputs.resourceId 
    webConfiguration: {
      netFrameworkVersion: 'v8.0'
      metadata: {
        name: 'CURRENT_STACK'
        value: 'dotnet'
      }
    }
    /* privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          webPrivateDnsZone.outputs.resourceId
        ]
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1] // Ensure correct subnet for app services
        tags: {
          Environment: 'lab'
        }
      }
    ] */
  }
}]
module feAppServices 'br/public:avm/res/web/site:0.13.1' = [for (app, i) in feAppConfig: {
  name: 'appDeploy-${app.name}'
  scope: resourceGroup
  params: {
    kind: app.kind
    location: app.location
    name: app.name
    serverFarmResourceId: app.location == primaryRegion ? serverFarm[0].outputs.resourceId : serverFarm[1].outputs.resourceId 
    webConfiguration: {
      netFrameworkVersion: 'v8.0'
      metadata: {
        name: 'CURRENT_STACK'
        value: 'dotnet'
      }
    }
    /* privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          webPrivateDnsZone.outputs.resourceId
        ]
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1] // Ensure correct subnet for app services
        tags: {
          Environment: 'lab'
        }
      }
    ] */
  }
}]

/* module webPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.3.0' = {
  name: 'apiPrivateDnsZoneDeployment1'
  scope: resourceGroup
  params: {
    name: 'privatelink.azurewebsites.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        name: 'webVnetLink'
        registrationEnabled: true
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
      {
        name: 'webVnetLink2'
        registrationEnabled: true
        virtualNetworkResourceId: virtualNetwork2.outputs.resourceId
      }
    ]
  }
} */

module sqlServer 'br/public:avm/res/sql/server:0.4.0' = {
  name: 'sqlServerDeployment1'
  scope: resourceGroup
  params: {
    name: sqlServerName
    administratorLogin: 'sqladmin'
    administratorLoginPassword: sqlpassword
    firewallRules: [
      {
        endIpAddress: '0.0.0.0'
        name: 'AllowAllWindowsAzureIps'
        startIpAddress: '0.0.0.0'
      }
    ]
    databases: [
      {
        name: 'apidb'
        maxSizeBytes: 2147483648
        skuName: 'GP_Gen5'
        skuTier: 'GeneralPurpose'
        skuCapacity: 2
        family: 'Gen5'
        collation: 'SQL_Latin1_General_CP1_CI_AS'
        requestedBackupStorageRedundancy: 'Geo'
        zoneredundant: zoneredundant
      }
    ]
    location: primaryRegion
  }
}
