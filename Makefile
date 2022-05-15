RG_NAME := 'container-app-dapr-rg'
LOCATION := 'canadacentral'
ENVIRONMENT := dev
VERSION := 0.1.0
TAG := ${ENVIRONMENT}-${VERSION}
DB_ADMIN_USERNAME := dbadmin
DB_ADMIN_PASSWORD := 'M1cr0soft1234567890'
FRONTEND_PORT="80"
BACKEND_PORT="81"

deploy_rg:
	az group create --location ${LOCATION} --name ${RG_NAME}

build:
	az deployment group create \
		--resource-group ${RG_NAME} \
		--name 'acr-deployment' \
		--parameters anonymousPullEnabled=true \
		--template-file ./infra/modules/acr.bicep; \
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/frontend:${TAG} --build-arg SERVICE_NAME="frontend" --build-arg SERVICE_PORT=${FRONTEND_PORT}  -f Dockerfile .; \
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/backend:${TAG} --build-arg SERVICE_NAME="backend" --build-arg SERVICE_PORT=${BACKEND_PORT} -f Dockerfile .;

deploy:
	az deployment group create \
		--resource-group ${RG_NAME} \
		--name 'infra-deployment' \
		--template-file ./infra/main.bicep \
		--parameters location=${LOCATION} \
		--parameters imageTag=${TAG} \
		--parameters frontendAppPort=${FRONTEND_PORT} \
		--parameters backendAppPort=${BACKEND_PORT} \
		--parameters acrName=$(shell az deployment group show --resource-group ${RG_NAME} --name 'acr-deployment' --query properties.outputs.acrName.value -o tsv)

	export SB_CXN_STR=$(shell az deployment group show --resource-group ${RG_NAME} --name 'infra-deployment' --query properties.outputs.sbConnectionString.value); \
	export COSMOS_ENDPOINT=$(shell az deployment group show --resource-group ${RG_NAME} --name 'infra-deployment' --query properties.outputs.cosmosEndpoint.value); \
	export COSMOS_KEY=$(shell az deployment group show --resource-group ${RG_NAME} --name 'infra-deployment' --query properties.outputs.cosmosKey.value); \
	jq ".servicebus.connectionString=env.SB_CXN_STR | .cosmosdb.endpoint=env.COSMOS_ENDPOINT | .cosmosdb.key=env.COSMOS_KEY" ./components/secrets_template.json > ./components/secrets.json

build_local:
	cd ./cmd/frontend; go build;
	cd ./cmd/backend; go build;

deploy_local:
	export SERVICE_NAME="frontend"; \
	export SERVICE_PORT="8000"; \
	export QUEUE_BINDING_NAME="servicebus"; \
	export QUEUE_NAME="checkin"; \
	dapr run --app-id frontend --app-port 8000 ./cmd/frontend/frontend --components-path ./components --log-level debug &

	export SERVICE_NAME="backend"; \
	export SERVICE_PORT="8001"; \
	export QUEUE_BINDING_NAME="servicebus"; \
	export STORE_BINDING_NAME="cosmosdb"; \
	dapr run --app-id backend --app-port 8001 ./cmd/backend/backend --components-path ./components --log-level debug &

test:
	curl "https://$(shell az deployment group show --resource-group ${RG_NAME} --name 'infra-deployment' --query properties.outputs.frontendFqdn.value -o tsv)/checkin" -d '{"user_id":"777","location_id":"77"}'

test_local:
	curl http://localhost:8000/checkin -d '{"user_id":"123","location_id":"5"}'