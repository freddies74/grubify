param name string
param location string = resourceGroup().location
param tags object = {}

@description('PostgreSQL administrator login name')
param administratorLogin string

@description('PostgreSQL administrator password')
@secure()
param administratorLoginPassword string

@description('SKU tier: Burstable, GeneralPurpose, or MemoryOptimized')
param skuTier string = 'Burstable'

@description('SKU name, e.g. Standard_B1ms')
param skuName string = 'Standard_B1ms'

@description('Storage size in GB')
param storageSizeGB int = 32

@description('PostgreSQL major version')
param version string = '16'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// Enable enhanced activity metrics for query-level observability.
// These allow correlating DB CPU alerts with session and query evidence
// instead of relying on top-level CPU metrics alone.
resource collectorDatabaseActivity 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: postgresServer
  name: 'metrics.collector_database_activity'
  properties: {
    value: 'on'
    source: 'user-override'
  }
}

resource autovacuumDiagnostics 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: postgresServer
  name: 'metrics.autovacuum_diagnostics'
  properties: {
    value: 'on'
    source: 'user-override'
  }
}

output id string = postgresServer.id
output name string = postgresServer.name
output fqdn string = postgresServer.properties.fullyQualifiedDomainName
