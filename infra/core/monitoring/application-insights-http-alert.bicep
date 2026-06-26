param namePrefix string
param location string = resourceGroup().location
param tags object = {}
param workspaceResourceId string

@minValue(1)
param failedRequestThreshold int = 5

@minValue(0)
@maxValue(4)
param severity int = 2

var applicationInsightsName = '${namePrefix}-appi'
var alertRuleName = '${namePrefix}-http-5xx-errors'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
  }
}

resource http5xxAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: alertRuleName
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    description: 'Fires when true HTTP 5xx requests exceed the threshold while ignoring known scanner-style probe paths such as .env and .git reconnaissance.'
    displayName: alertRuleName
    enabled: true
    severity: severity
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            AppRequests
            | where _ResourceId =~ '${applicationInsights.id}'
            | extend StatusCode = toint(ResultCode)
            | extend RequestPath = tolower(tostring(parse_url(Url).Path))
            | where StatusCode between (500 .. 599)
            | where RequestPath !contains '/.env'
            | where RequestPath !contains '.git-credentials'
            | where RequestPath !contains '/.git/'
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: failedRequestThreshold
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    skipQueryValidation: false
    targetResourceTypes: [
      'microsoft.operationalinsights/workspaces'
    ]
  }
}
