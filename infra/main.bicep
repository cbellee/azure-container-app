param location string
param imageTag string
param acrName string
param frontendAppPort string
param backendAppPort string
param tags object = {
  environment: 'dev'
  costcode: '1234567890'
}

var prefix = uniqueString(resourceGroup().id)

var containerAppEnvName = '${prefix}-app-env'
var frontEndContainerImage = '${acr.properties.loginServer}/frontend:${imageTag}'
var backendContainerImage = '${acr.properties.loginServer}/backend:${imageTag}'
var backendAppName = 'backend'
var frontendAppName = 'frontend'
var sbBindingName = 'servicebus'
var cosmosBindingName = 'cosmosdb'

var acrLoginServer = '${acrName}.azurecr.io'
var acrAdminPassword = listCredentials(acr.id, '2021-12-01-preview').passwords[0].value

var workspaceName = '${prefix}-wks'

var sbNamespace = 'checkins'
var cosmosName = '${prefix}-cosmosdb'
var cosmosDbName = 'checkinDb'
var cosmosPartitionKey = 'user_id'
var aiName = '${prefix}-ai'
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
    location: location
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

module containerAppEnvModule './modules/cappenv.bicep' = {
  name: 'cappDeployment'
  params: {
    name: containerAppEnvName
    location: location
    tags: tags
    wksSharedKey: wksModule.outputs.workspaceSharedKey
    aiKey: aiModule.outputs.aiKey
    wksCustomerId: wksModule.outputs.workspaceCustomerId
  }
}

/* resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  location: location
  name: containerAppEnvName
  properties: {
    daprAIInstrumentationKey: aiModule.outputs.aiKey
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
 */

resource frontEndApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: frontendAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    containerAppEnvModule
    cosmosModule
    sbModule
  ]
  properties: {
    configuration: {
      activeRevisionsMode: 'single'
      dapr: {
        appId: frontendAppName
        appPort: int(frontendAppPort)
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
        targetPort: int(frontendAppPort)
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        transport: 'http'
      }
    }
    managedEnvironmentId: containerAppEnvModule.outputs.id
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
              value: frontendAppPort
            }
            {
              name: 'QUEUE_BINDING_NAME'
              value: sbBindingName
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

resource backEndApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: backendAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    containerAppEnvModule
    cosmosModule
    sbModule
  ]
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
        appPort: int(backendAppPort)
        appProtocol: 'http'
        enabled: true
      }
      ingress: {
        external: false
        targetPort: int(backendAppPort)
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        transport: 'http'
      }
    }
    managedEnvironmentId: containerAppEnvModule.outputs.id
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
              value: backendAppPort
            }
            {
              name: 'QUEUE_BINDING_NAME'
              value: sbBindingName
            }
            {
              name: 'STORE_BINDING_NAME'
              value: cosmosBindingName
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

resource serviceBusDaprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: '${containerAppEnvName}/${sbBindingName}'
  properties: {
    componentType: 'bindings.azure.servicebusqueues'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '60s'
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
      frontendAppName
      backendAppName
    ]
  }
}

resource cosmosDbDaprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: '${containerAppEnvName}/${cosmosBindingName}'
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
      backendAppName
    ]
  }
}

output frontendFqdn string = frontEndApp.properties.configuration.ingress.fqdn
output sbConnectionString string = sbModule.outputs.connectionString
output cosmosEndpoint string = cosmosModule.outputs.endpointUri
output cosmosKey string = cosmosModule.outputs.masterKey
