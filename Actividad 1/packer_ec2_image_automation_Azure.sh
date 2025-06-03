#!/usr/bin/env bash
set -euo pipefail

RG="rg-autodeploy"
LOCATION=${AZURE_LOCATION:-eastus2}
NSG_NAME="nsg-autodeploy"
IMG_RG="rg-packer-images"

echo "▶ 1.  Make sure we are logged in"
az account show >/dev/null 2>&1 || az login --service-principal \
      -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"

echo "▶ 2.  Resource group for the VM"
az group create --location "$LOCATION" --name "$RG" >/dev/null

echo "▶ 3.  Build image with Packer"
packer build -color=false template.pkr.hcl

IMG_ID=$(jq -r '.builds[0].artifact_id | split(":")[1]' packer-manifest.json)
echo "   Managed image id: $IMG_ID"

echo "▶ 4.  Network security group + rules"
az network nsg create \
   --resource-group "$RG" \
   --name "$NSG_NAME" \
   --location "$LOCATION" >/dev/null

for PORT in 22 80 443; do
  az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG_NAME" \
    --name "allow-$PORT" \
    --priority $((1000+PORT)) \
    --access Allow --protocol Tcp --direction Inbound --destination-port-range "$PORT" >/dev/null
done

echo "▶ 5.  Deploy VM from the image"
az vm create \
   --resource-group "$RG" \
   --name "adc-vm" \
   --image "$IMG_ID" \
   --admin-username azureuser \
   --generate-ssh-keys \
   --size Standard_B1s \
   --nsg "$NSG_NAME" \
   --public-ip-sku Standard \
   --tags project=ADC purpose=demo

IP=$(az vm show -d -g "$RG" -n "adc-vm" --query publicIps -o tsv)
echo "VM online ➜ http://$IP  (takes ~30 s for Nginx to answer)"