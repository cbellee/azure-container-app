param location string = resourceGroup().location
param imageTag string
param acrName string
param tags object = {
  environment: 'dev'
  costcode: '1234567890'
}

var frontEndContainerImage = '${acr.properties.loginServer}/frontend:${imageTag}'
var backendContainerImage = '${acr.properties.loginServer}/backend:${imageTag}'
var acrLoginServer = '${acrName}.azurecr.io'
var acrAdminPassword = listCredentials(acr.id, '2021-12-01-preview').passwords[0].value
var affix = uniqueString(resourceGroup().id)
var workspaceName = '${affix}-wks'
var containerAppEnvName = '${affix}-app-env'
var backendAppName = 'backend'
var frontendAppName = 'frontend'
var sbNamespace = 'checkins'
var cosmosName = '${affix}-cosmosdb'
var cosmosDbName = 'checkinDb'
var cosmosPartitionKey = 'user_id'
var aiName = '${affix}-ai'
var secrets = [
  {
    name: 'registry-password'
    value: acrAdminPassword
  }
]

module aiModule 'modules/ai.bicep' = {
  name: 'aiDeployment'
  params: {
    location: location
    aiName: aiName
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: acrName
}

module wksModule 'modules/wks.bicep' = {
  name: 'wksDeployment'
  params: {
    location: location
    name: workspaceName
    tags: tags
  }
}

module sbModule 'modules/sbus.bicep' = {
  name: 'sbDeployment'
  params: {
    name: sbNamespace
    tags: tags
  }
}

module cosmosModule 'modules/cosmosdb.bicep' = {
  name: 'cosmosDeployment'
  params: {
    name: cosmosName
    location: location
    dbName: cosmosDbName
    partitionKey: cosmosPartitionKey
    tags: tags
  }
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  location: location
  name: containerAppEnvName
  properties: {
    daprAIInstrumentationKey: aiModule.outputs.aiKey
    vnetConfiguration: {
      internal: false
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: wksModule.outputs.workspaceCustomerId
        sharedKey: wksModule.outputs.workspaceSharedKey
      }
    }
  }
  tags: tags
}

resource frontEndApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: frontendAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'single'
      dapr: {
        appId: frontendAppName
        appPort: 80
        appProtocol: 'http'
        enabled: true
      }
      secrets: secrets
      registries: [
        {
          passwordSecretRef: 'registry-password'
          server: acrLoginServer
          username: acr.name
        }
      ]
      ingress: {
        external: true
        targetPort: 80
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        transport: 'http'
      }
    }
    managedEnvironmentId: containerAppEnvironment.id
    template: {
      containers: [
        {
          image: frontEndContainerImage
          name: frontendAppName
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'SERVICE_NAME'
              value: frontendAppName
            }
            {
              name: 'SERVICE_PORT'
              value: '80'
            }
            {
              name: 'QUEUE_BINDING_NAME'
              value: 'servicebus'
            }
            {
              name: 'QUEUE_NAME'
              value: sbModule.outputs.queueName
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

resource backEndApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: backendAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'single'
      secrets: secrets
      registries: [
        {
          passwordSecretRef: 'registry-password'
          server: acrLoginServer
          username: acr.name
        }
      ]
      dapr: {
        appId: backendAppName
        appPort: 81
        appProtocol: 'http'
        enabled: true
      }
      ingress: {
        external: false
        targetPort: 81
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        transport: 'http'
      }
    }
    managedEnvironmentId: containerAppEnvironment.id
    template: {
      containers: [
        {
          image: backendContainerImage
          name: backendAppName
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'SERVICE_NAME'
              value: backendAppName
            }
            {
              name: 'SERVICE_PORT'
              value: '81'
            }
            {
              name: 'QUEUE_BINDING_NAME'
              value: 'servicebus'
            }
            {
              name: 'STORE_BINDING_NAME'
              value: 'cosmosdb'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

resource serviceBusDaprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
  name: 'servicebus'
  parent: containerAppEnvironment
  properties: {
    componentType: 'bindings.azure.servicebusqueues'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5s'
    metadata: [
      {
        name: 'connectionString'
        value: sbModule.outputs.connectionString
      }
      {
        name: 'queueName'
        value: sbModule.outputs.queueName
      }
      {
        name: 'ttlInSeconds'
        value: '60'
      }
    ]
    scopes: [
      frontEndApp.name
      backEndApp.name
    ]
  }
}

resource cosmosDbDaprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
  name: 'cosmosdb'
  parent: containerAppEnvironment
  properties: {
    componentType: 'bindings.azure.cosmosdb'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '60s'
    metadata: [
      {
        name: 'url'
        value: cosmosModule.outputs.endpointUri
      }
      {
        name: 'masterKey'
        value: cosmosModule.outputs.masterKey
      }
      {
        name: 'database'
        value: cosmosModule.outputs.dbName
      }
      {
        name: 'collection'
        value: cosmosModule.outputs.collectionName
      }
      {
        name: 'partitionKey'
        value: cosmosPartitionKey
      }
    ]
    scopes: [
      backEndApp.name
    ]
  }
}

output frontendFqdn string = frontEndApp.properties.latestRevisionFqdn
output backendFqdn string = backEndApp.properties.latestRevisionFqdn
