#!/bin/bash

while getopts "g:s:c:a:i:t:o:" opt; do
    case $opt in
        g) GROUP_NAME="$OPTARG";;
        s) SERVICE_PRINCIPAL_NAME="$OPTARG";;
        c) ACR_NAME="$OPTARG";;
        a) APP_NAME="$OPTARG";;
        i) APP_IMAGE="$OPTARG";;
        t) TAG="$OPTARG";;
        o) OPTION="$OPTARG";;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1;; 
    esac
done

if [ -z "$GROUP_NAME" ] || [ -z "$SERVICE_PRINCIPAL_NAME" ] || [ -z "$ACR_NAME" ] || [ -z "$APP_NAME" ] || [ -z "$APP_IMAGE" ] || [ -z "$TAG" ]; then
    echo -e "\033[31:1mError:\033[0m You must provide arguments for the -g, -s, -c, -a, -i and -t options."
    exit 1
fi

for i in $(az group list --output tsv | awk '{print $4}')
do
    if [ "$GROUP_NAME" == "$i" ]; then
        echo "$GROUP_NAME al ready exists."
        GROUP_EXISTS="yes" 
    fi
done

if [ "$GROUP_EXISTS" != "yes" ]; then
    echo -e "\033[32mCreating group $GROUP_NAME...\033[0m"
    az group create --name "$GROUP_NAME" --location eastus
fi

echo -e "\033[32mCreating container registry...\033[0m"
az acr create --resource-group "$GROUP_NAME" --name "$ACR_NAME" --sku Basic --admin-enabled true

echo -e "\033[32mLogging into the container registry...\033[0m"
az acr login --name "$ACR_NAME"

echo -e "\033[32mGetting acr registry id...\033[0m"
ACR_REGISTRY_ID=$(az acr show --name "$ACR_NAME" --query "id" --output tsv)

echo -e "\033[32mGetting username...\033[0m"
USER_NAME=$(az ad sp list --display-name "$SERVICE_PRINCIPAL_NAME" --query "[].appId" --output tsv)

echo -e "\033[32mGetting password...\033[0m"
PASSWORD=$(az ad sp create-for-rbac --name "$SERVICE_PRINCIPAL_NAME" --scopes "$ACR_REGISTRY_ID" --role acrpull --query "password" --output tsv)

repoList(){
    echo -e "\033[32mGetting repository list from container registry...\033[0m"
    az acr repository list --name "$ACR_NAME" --output table
}
build(){
    echo -e "\033[32mBuilding image...\033[0m"
    docker build -t "$APP_IMAGE":"$TAG" .

    echo -e "\033[32mUploading tag to container registry...\033[0m"
    docker tag "$APP_IMAGE":"$TAG" "$ACR_NAME".azurecr.io/"$APP_IMAGE":"$TAG"

    echo -e "\033[32mContainer list: \033[0m"
    docker images

    echo -e "\033[32mUploading image to container registry...\033[0m"
    docker push "$ACR_NAME".azurecr.io/"$APP_IMAGE":"$TAG"

    repoList
}

deploy(){
    echo -e "\033[32mCreating instance...\033[0m"
    az container create --resource-group "$GROUP_NAME" --name "$APP_NAME" --image "$ACR_NAME".azurecr.io/"$APP_IMAGE":"$TAG" --cpu 1 --memory 1 --registry-login-server "$ACR_NAME".azurecr.io --registry-username "$USER_NAME" --registry-password "$PASSWORD" --ip-address Public --dns-name-label dns-um-"$RANDOM" --ports 5000 --query ipAddress.fqdn
}

if [ "$OPTION" == "build" ]; then
    build
elif [ "$OPTION" == "deploy" ]; then
    repoList
    deploy
else
    build
    deploy
fi

echo -e "\033[32:1mDone.\033[0m"
