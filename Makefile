RG_NAME := 'container-app-dapr-1-rg'
LOCATION := 'canadacentral'
ENVIRONMENT := dev
VERSION := 0.1.0
TAG := ${ENVIRONMENT}-${VERSION}

build:
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/frontend:${TAG} --build-arg SERVICE_NAME="frontend"  -f Dockerfile .
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/backend:${TAG} --build-arg SERVICE_NAME="backend"  -f Dockerfile .

build_local:
	docker build -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/frontend:${TAG} --build-arg SERVICE_NAME="frontend" .
	docker build -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/backend:${TAG} --build-arg SERVICE_NAME="backend" .

deploy:
	az group create --location ${LOCATION} --name ${RG_NAME}

	az deployment group create \
		--resource-group ${RG_NAME} \
		--name 'infra-deployment' \
		--template-file ./infra/main.bicep \
		--parameters imageTag=${TAG}

test:
	curl "$(shell az deployment group show --resource-group ${RG_NAME} --name 'infra-deployment' --query properties.outputs.frontendFqdn.value -o tsv)/checkin" -d '{"user_id":"123","location_id":"5"}'
