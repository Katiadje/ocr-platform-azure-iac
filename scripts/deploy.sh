#!/bin/bash
# deploy.sh - script de déploiement complet de la plateforme OCR
# usage: ./scripts/deploy.sh [dev|prod]

set -e  # arrêter si une commande échoue

ENV=${1:-dev}
echo "=== Déploiement de la plateforme OCR - Environnement : $ENV ==="

# vérifier que les outils sont dispo
command -v terraform >/dev/null 2>&1 || { echo "terraform non installé !"; exit 1; }
command -v az >/dev/null 2>&1       || { echo "Azure CLI non installé !"; exit 1; }

# vérifier qu'on est connecté à Azure
az account show >/dev/null 2>&1 || { echo "Pas connecté à Azure, faire 'az login' d'abord !"; exit 1; }

echo ""
echo "=== 1/4 - Création du backend Terraform (si pas déjà fait) ==="

# créer le resource group pour le state Terraform
az group create \
  --name rg-terraform-state \
  --location westeurope \
  --output none 2>/dev/null || true

# créer le storage account pour le state
az storage account create \
  --name sttfstate0ocr \
  --resource-group rg-terraform-state \
  --location westeurope \
  --sku Standard_LRS \
  --output none 2>/dev/null || true

# créer le container tfstate
az storage container create \
  --name tfstate \
  --account-name sttfstate0ocr \
  --output none 2>/dev/null || true

echo "Backend OK"

echo ""
echo "=== 2/4 - Initialisation Terraform ==="
terraform init -reconfigure

echo ""
echo "=== 3/4 - Terraform plan ==="
terraform plan \
  -var="environment=$ENV" \
  -out="tfplan-$ENV"

echo ""
read -p "Voulez-vous appliquer ce plan ? (y/n) " confirm
if [ "$confirm" != "y" ]; then
  echo "Déploiement annulé."
  exit 0
fi

echo ""
echo "=== 4/4 - Terraform apply ==="
terraform apply "tfplan-$ENV"

echo ""
echo "=== Déploiement terminé ! ==="
echo ""
echo "Outputs importants :"
terraform output function_app_url
terraform output storage_account_name
terraform output images_container_name

echo ""
echo "Pour déployer la Function App :"
echo "  cd function && func azure functionapp publish \$(terraform output -raw function_app_name)"
