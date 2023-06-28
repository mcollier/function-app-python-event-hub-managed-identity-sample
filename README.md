# Python Azure Function with Event Hub using Identity Based Connections

_This is a sample project that is currently under development. Use at your own risk._

## Getting started

- Copy the `sample.env` to a local `.env` file, and update the settings as appropriate.
- Authenticate with Azure using the Azure CLI command `az login`.
- Set the necessary Azure subscription using the `az account set -s [YOUR-SUBSCRIPTION-ID]` command.
- Run the `deploy-and-publish.sh` script to provision the Azure resources, zip, and upload the deployment package file.

### Notes

- The `deploy-and-publish.sh` script will attempt to assign the `USER_PRINCIPAL_NAME` (in the .env file) to the Storage Blob Data Contributor role.
- The project does not _yet_ support the Azure Developer CLI (AZD).  AZD support is a goal for a future update.