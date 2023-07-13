#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ ! -f "$script_dir/.env" ]]; then
	echo "Please create a .env file (using sample.env as a starter)" 1>&2
	exit 1
fi
source "$script_dir/.env"

LOCATION=${LOCATION:-eastus}
STORAGE_CONTAINER_NAME="deployment"

echo -e "\n== Deploying main resources via Azure Developer CLI (AZD)"
azd provision

# Load the AZD environment variables (containing outputs of the AZD command)
source "$script_dir/.azure/pythonfunction1/.env"

# Create the package
pushd src

pip install --target "./.python_packages/lib/site-packages" -r ./requirements.txt --upgrade
# pip install --target "./src/.python_packages/lib/site-packages" -r ./src/requirements.txt --upgrade

zip -r function.zip . \
    -x ".devcontainer/*" \
    -x ".vscode/*" \
    -x ".venv/*" \
    -x "*.sh" \
    -x ".gitignore" \
    -x "local.settings.json" \
    -x "function/*"

# Use AZD to create the package (zip) file.
# echo -e "\n== Creating the package (zip) file using the Azure Developer CLI (AZD)"
# azd package

# TODO: How to get the path to the package created by AZD?

# Upload and set the package
PACKAGE_URL="https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/$STORAGE_CONTAINER_NAME/function.zip"
STORAGE_ROLE_NAME="Storage Blob Data Contributor"

echo -e "\n== Assigning $STORAGE_ROLE_NAME role to $USER_PRINCIPAL_NAME in order to upload deployment package."

# Assign self the 'Storage Blob Data Contributor' role
az role assignment create \
    --assignee "$USER_PRINCIPAL_NAME" \
    --role "$STORAGE_ROLE_NAME" \
    --scope "$STORAGE_ACCOUNT_RESOURCE_ID"

# Sleep to give AAD time to replicate data.
echo -e "\n== Sleeping for 15 seconds . . ."
sleep 15

az storage blob upload \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --container-name "$STORAGE_CONTAINER_NAME" \
    --name function.zip \
    --file function.zip \
    --overwrite \
    --auth-mode login

az functionapp config appsettings set \
    -g "$RESOURCE_GROUP_NAME" \
    -n "$FUNCTION_APP_NAME" \
    --settings WEBSITE_RUN_FROM_PACKAGE="$PACKAGE_URL"

popd