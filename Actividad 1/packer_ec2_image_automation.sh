#!/bin/bash

set -euo pipefail
INSTANCE_ID="UNIR_DevOpsTools_Auto"


echo "=== [1] Obteniendo la VPC predeterminada ==="
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
if [ -z "$VPC_ID" ]; then
  echo "No se encontró una VPC predeterminada. Asegúrate de tener una VPC creada o modifícalo para crear una nueva."
  exit 1
fi
echo "VPC predeterminada encontrada: ${VPC_ID}"

echo "=== [2] Pasando la subred de la VPC ${VPC_ID} ==="
# Especifica la zona de disponibilidad y el rango CIDR para la subred
AVAILABILITY_ZONE="XX-XXXX-XX"
SUBNET_CIDR="XXX.XX.XX.X/XX"
SUBNET_ID="subnet-XXXXXXXXXXXXXXXXX"

echo "=== [3] Creando el grupo de seguridad ==="
GROUP_NAME="AutoDeploySG"
DESCRIPTION="Grupo de seguridad para despliegue automatizado"
# Comprobar si ya existe un grupo de seguridad con ese nombre
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${GROUP_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
  --query 'SecurityGroups[*].GroupId' --output text)

if [ -z "$SECURITY_GROUP_ID" ]; then
  echo "El grupo de seguridad ${GROUP_NAME} no existe. Se creará uno nuevo..."
  # Crear el grupo de seguridad
  new_sg=$(aws ec2 create-security-group \
    --group-name "${GROUP_NAME}" \
    --description "${DESCRIPTION}" \
    --vpc-id "${VPC_ID}" \
    --query 'GroupId' --output text)
  echo "Grupo de seguridad creado: ${new_sg}"
  SECURITY_GROUP_ID="$new_sg"
  echo "=== [4] Configurando reglas en el grupo de seguridad ==="
  # Permitir SSH (puerto 22), HTTP (80) y HTTPS (443) desde cualquier IP 
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0
  echo "Reglas configuradas correctamente."
else
  echo "El grupo de seguridad ya existe: ${SECURITY_GROUP_ID}"
fi

echo "=== [5] Ejecutando el build con Packer ==="
PACKER_OUTPUT=$(packer build template_original.pkr.hcl)

# Extraer el AMI ID de la salida de Packer. Esto depende del formato exacto de la salida.
AMI_ID=$(echo "$PACKER_OUTPUT" | grep 'ami-' | head -1 | awk '{print $NF}')
if [ -z "$AMI_ID" ]; then
    echo "Error: No se pudo extraer el AMI ID del proceso de Packer."
    exit 1
fi
echo "AMI creada con éxito: ${AMI_ID}"

echo "=== [6] Desplegando la instancia EC2 ==="
aws ec2 run-instances --image-id "$AMI_ID" --instance-type t2.micro --key-name DevOpsToolsEC2Keys \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=UNIR_DevOpsTools_Auto}]'
echo "Instancia desplegada exitosamente."