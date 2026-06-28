param name string
param location string = resourceGroup().location
param tags object = {}

@description('PostgreSQL administrator login name')
param administratorLogin string

@description('PostgreSQL administrator login password')
@secure()
param administratorLoginPassword string

@description('PostgreSQL version')
param version string = '16'

@description('SKU name for the PostgreSQL flexible server')
param skuName string = 'Standard_D2s_v3'

@description('Compute tier for the PostgreSQL flexible server')
param tier string = 'GeneralPurpose'

@description('Storage size in GB')
param storageSizeGB int = 32

@description('Backup retention in days')
param backupRetentionDays int = 7

@description('Enable geo-redundant backups')
param geoRedundantBackup string = 'Disabled'

@description('High availability mode')
param highAvailabilityMode string = 'Disabled'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: tier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailabilityMode
    }
  }
}

output id string = postgresServer.id
output name string = postgresServer.name
output fqdn string = postgresServer.properties.fullyQualifiedDomainName
