RG_NAME := 'container-app-dapr-rg'
LOCATION := 'canadacentral'
ENVIRONMENT := dev
VERSION := 0.1.0
TAG := ${ENVIRONMENT}-${VERSION}
DB_ADMIN_USERNAME := dbadmin
DB_ADMIN_PASSWORD := 'M1cr0soft1234567890'

rg:
	az group create --location ${SPOKE_LOCATION} --name ${RG_NAME}

build:
	az deployment group create \
		--resource-group ${RG_NAME} \
		--name 'acr-deployment' \
		--parameters anonymousPullEnabled=true \
		--template-file ./infra/modules/acr.bicep

	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/frontend:${TAG} --build-arg SERVICE_NAME="frontend"  -f Dockerfile .
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/backend:${TAG} --build-arg SERVICE_NAME="backend"  -f Dockerfile .

deploy:
	az deployment group create \
		--resource-group ${RG_NAME} \
		--name 'infra-deployment' \
		--template-file ./infra/main.bicep \
		--parameters location=${LOCATION} \
		--parameters imageTag=${TAG} \
		--parameters acrName=$(shell az deployment group show --resource-group ${RG_NAME} --name 'acr-deployment' --query properties.outputs.acrName.value -o tsv)

build_local:
	docker build -t frontend:${TAG} --build-arg SERVICE_NAME="frontend" .
	docker build -t backend:${TAG} --build-arg SERVICE_NAME="backend" .

test:
	curl "$(shell az deployment group show --resource-group ${RG_NAME} --name 'infra-deployment' --query properties.outputs.frontendFqdn.value -o tsv)/checkin" -d '{"user_id":"123","location_id":"5"}'

test_local:
	curl http://localhost:8080/checkin -d '{"user_id":"123","location_id":"5"}'