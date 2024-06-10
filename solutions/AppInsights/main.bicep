@description('The location for all resources.')
param location string = resourceGroup().location

@description('The name of the Application Insights instance.')
param appInsightsName string

@description('The name of the web test.')
param webTestName string

@description('The name of the existing Log Analytics workspace.')
param logAnalyticsWorkspaceName string

@description('The resource group of the existing Log Analytics workspace.')
param logAnalyticsWorkspaceResourceGroup string

@description('The name of the alert rule.')
param alertRuleName string

@description('The name of the action group.')
param actionGroupName string

@description('The email address for the action group notifications.')
param notificationEmail string

@description('The URL to be monitored by the web test.')
param webTestUrl string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource webTest 'Microsoft.Insights/webtests@2020-02-02' = {
  name: webTestName
  location: location
  properties: {
    SyntheticMonitorId: webTestName
    WebTestName: webTestName
    Locations: [
      {
        Id: 'us-fl-mia-edge'
      }
    ]
    Configuration: {
      WebTest: {
        "@odata.type": 'microsoft.insights.webtest'
        SyntheticMonitorId: webTestName
        Name: webTestName
        Enabled: true
        Frequency: 300
        Locations: [
          {
            Id: 'us-fl-mia-edge'
          }
        ]
        Configuration: {
          Url: webTestUrl
          Timeout: 120
          VerbosityLevel: 0
          ValidationRules: {
            ExpectedHttpStatusCode: 200
            ContentValidationRules: []
          }
        }
      }
    }
    Kind: 'ping'
  }
}

resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroup)
}

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2020-01-01' = {
  name: '${webTestName}-diagnostic'
  scope: webTest
  properties: {
    workspaceId: existingLogAnalyticsWorkspace.id
    logs: [
      {
        category: 'WebTestLog'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2020-02-02' = {
  name: actionGroupName
  location: location
  properties: {
    groupShortName: actionGroupName
    enabled: true
    emailReceivers: [
      {
        name: 'emailReceiver'
        emailAddress: notificationEmail
      }
    ]
  }
}

resource alertRule 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertRuleName
  location: location
  properties: {
    description: 'Alert when the web test does not return a 200 status code for over 5 minutes'
    severity: 3
    enabled: true
    scopes: [
      webTest.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          metricName: 'FailedLocations'
          metricNamespace: 'microsoft.insights/webtests'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          dimensions: []
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
