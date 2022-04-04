param environmentId string
param location string = resourceGroup().location
param imageName string
param appName string
param acrPassword string
param acrName string
param acrLoginServer string
param envVars array = []
param tags object = {}
param isExternal bool = false
param containerPort int
param minReplicas int = 0
param maxReplicas int = 10
param daprConfig object = {}
param secrets array = [
  {
    name: 'registry-password'
    value: acrPassword
  }
]

@allowed([
  'multiple'
  'single'
])
param revisionMode string = 'multiple'

resource containerApp 'Microsoft.Web/containerApps@2021-03-01' = {
  name: appName
  kind: 'containerapp'
  location: location
  properties: {
    kubeEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: revisionMode
      secrets: secrets
      registries: [
        {
          server: acrLoginServer
          username: acrName
          passwordSecretRef: 'registry-password'
        }
      ]
      ingress: {
        external: isExternal
        targetPort: containerPort
        transport: 'auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }
    template: {
      containers: [
        {
          image: imageName
          name: appName
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
          env: envVars
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
      dapr: daprConfig
    }
  }
  tags: tags
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
