param name string
param location string = resourceGroup().location
param tags object = {}

@description('Resource ID of the Log Analytics workspace to back this Application Insights instance.')
param logAnalyticsWorkspaceId string

@description('Slow-response alert threshold in milliseconds. Requests whose rolling average exceeds this value will fire an alert. Default: 5000 ms.')
param slowResponseThresholdMs int = 5000

@description('Evaluation window and frequency for the slow-response alert (ISO 8601 duration). Default: PT5M (5 minutes).')
param alertWindowSize string = 'PT5M'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    RetentionInDays: 30
  }
}

// Scheduled query rule alert that evaluates only customer-facing requests.
// Internal managed-identity (MSI) token calls to localhost endpoints are
// excluded from the query so that slow auth-bootstrap traffic during
// environment bring-up cannot trigger a false-positive latency alert
// (root cause of incident ai-Zava-xnfiyr).
resource slowCustomerResponseAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: '${name}-slow-customer-response'
  location: location
  tags: tags
  properties: {
    description: 'Fires when the 5-minute average duration of customer-facing requests exceeds ${slowResponseThresholdMs} ms. Internal localhost/MSI token requests are excluded to prevent false positives during environment bring-up.'
    severity: 2
    enabled: true
    evaluationFrequency: alertWindowSize
    windowSize: alertWindowSize
    scopes: [
      applicationInsights.id
    ]
    criteria: {
      allOf: [
        {
          // Exclude internal localhost endpoints (e.g. http://localhost:<port>/msi/token)
          // so that managed-identity credential bootstrap calls are not counted toward
          // the customer latency SLO.
          query: '''requests
| where url !startswith "http://localhost"
| where url !startswith "https://localhost"
| where url !contains "/msi/token"
| summarize avg_duration_ms = avg(duration)
| where isnotnull(avg_duration_ms)'''
          timeAggregation: 'Count'
          metricMeasureColumn: 'avg_duration_ms'
          operator: 'GreaterThan'
          threshold: slowResponseThresholdMs
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
  }
}

output id string = applicationInsights.id
output name string = applicationInsights.name
output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
