param name string
param location string = resourceGroup().location
param tags object = {}
param scopes array
param actionGroupResourceIds array = []
param minRequestCount int = 100
param minServerErrorCount int = 5
param minErrorRatePercent int = 5

var query = format(
  'requests\n| where timestamp >= ago(5m)\n| summarize TotalRequests = count(), ServerErrors = countif(toint(resultCode) between (500 .. 599))\n| extend ErrorRatePercent = iff(TotalRequests == 0, 0.0, todouble(ServerErrors) * 100.0 / todouble(TotalRequests))\n| where TotalRequests >= {0}\n| where ErrorRatePercent >= {1}\n| where ServerErrors >= {2}\n| project AggregatedValue = ServerErrors',
  minRequestCount,
  minErrorRatePercent,
  minServerErrorCount
)

resource http5xxAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: name
  location: location
  kind: 'LogAlert'
  tags: tags
  properties: {
    description: 'Alerts only on true HTTP 5xx responses when traffic volume and error rate indicate a customer-facing problem.'
    displayName: name
    enabled: true
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: scopes
    criteria: {
      allOf: [
        {
          query: query
          timeAggregation: 'Maximum'
          metricMeasureColumn: 'AggregatedValue'
          operator: 'GreaterThanOrEqual'
          threshold: minServerErrorCount
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: actionGroupResourceIds
    }
    skipQueryValidation: true
  }
}
