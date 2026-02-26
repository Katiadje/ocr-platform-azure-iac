# OCR Platform — Infrastructure as Code & IA

Projet M2 - Déploiement d'une plateforme d'extraction de texte d'images sur Azure avec Terraform.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Resource Group                        │
│                                                                  │
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐  │
│  │ Blob Storage │───▶│  Azure Function  │───▶│ Azure AI Vision│  │
│  │ (images-    │    │  (Blob Trigger)  │    │ (OCR / ReadAPI)│  │
│  │  input)     │    │                  │    └────────────────┘  │
│  └─────────────┘    │  Managed Identity│           │            │
│                     └──────────────────┘           │            │
│  ┌─────────────┐           │                       │            │
│  │ Blob Storage │◀──────────┘                       │            │
│  │ (ocr-results)│   Résultat JSON                  │            │
│  └─────────────┘                                   │            │
│                                                    │            │
│  ┌─────────────────┐    ┌──────────────────────────┘            │
│  │   Azure Key      │    │ Clé API Vision stockée                │
│  │   Vault          │◀───┘ en secret Key Vault                  │
│  └─────────────────┘                                             │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │       Virtual Network (10.0.0.0/16)                       │   │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐  │   │
│  │  │ snet-functions   │  │ snet-services                │  │   │
│  │  │ (10.0.1.0/24)   │  │ (10.0.2.0/24)               │  │   │
│  │  └──────────────────┘  └──────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Application Insights + Log Analytics (monitoring)         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Services déployés

| Service | Rôle | SKU |
|---|---|---|
| Azure Blob Storage | Stockage images + résultats OCR | Standard LRS |
| Azure Functions | Traitement serverless (trigger blob) | Consumption Y1 |
| Azure AI Vision | API OCR (Read API) | S1 |
| Azure Key Vault | Gestion des secrets | Standard |
| Application Insights | Monitoring & logs | PerGB2018 |
| Virtual Network | Isolation réseau | - |

## Flux fonctionnel

1. **Dépôt** — Upload d'une image dans le container `images-input`
2. **Stockage** — Azure Blob Storage conserve l'image
3. **Déclenchement** — Le Blob Trigger active automatiquement la Function
4. **Analyse OCR** — La Function appelle Azure AI Vision (Read API)
5. **Stockage texte** — Le résultat JSON est sauvegardé dans `ocr-results`

## Structure du projet

```
ocr-platform/
├── main.tf                    # Point d'entrée, appelle tous les modules
├── variables.tf               # Variables globales
├── outputs.tf                 # Outputs après déploiement
├── terraform.tfvars           # Valeurs par défaut (env dev)
├── .gitignore
├── modules/
│   ├── network/               # VNet, subnets, NSG
│   ├── storage/               # Storage accounts, containers blob
│   ├── cognitive_service/     # Azure AI Vision + Key Vault
│   ├── compute/               # Function App, Service Plan, RBAC
│   └── monitoring/            # Application Insights, Log Analytics
├── function/
│   ├── host.json
│   ├── requirements.txt
│   └── ocr_function/
│       ├── __init__.py        # Code Python de la Function
│       └── function.json      # Config trigger blob
├── scripts/
│   └── deploy.sh              # Script de déploiement complet
└── .github/
    └── workflows/
        └── terraform.yml      # Pipeline CI/CD GitHub Actions
```

## Prérequis

- Terraform >= 1.3.0
- Azure CLI
- Un compte Azure avec une souscription active
- Python 3.11+ (pour la Function)

## Déploiement

### 1. Connexion Azure

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

### 2. Déploiement automatique

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh dev    # environnement de développement
./scripts/deploy.sh prod   # environnement de production
```

### 3. Déploiement manuel (étape par étape)

```bash
# Créer le backend Terraform manuellement (une seule fois)
az group create --name rg-terraform-state --location westeurope
az storage account create --name sttfstate0ocr --resource-group rg-terraform-state --location westeurope --sku Standard_LRS
az storage container create --name tfstate --account-name sttfstate0ocr

# Initialiser et déployer
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

### 4. Déployer la Function App

```bash
cd function
pip install azure-functions-core-tools
func azure functionapp publish $(terraform output -raw function_app_name)
```

## Tester la plateforme

```bash
# Uploader une image de test
az storage blob upload \
  --account-name $(terraform output -raw storage_account_name) \
  --container-name images-input \
  --name test.png \
  --file ./test.png \
  --auth-mode login

# Vérifier le résultat OCR (après ~30 secondes)
az storage blob list \
  --account-name $(terraform output -raw storage_account_name) \
  --container-name ocr-results \
  --auth-mode login \
  --output table
```

## Sécurité

- **Managed Identity** : La Function App utilise une identité managée system-assigned pour s'authentifier sans secret explicite
- **Key Vault** : La clé Azure AI Vision est stockée dans Key Vault, jamais en dur dans le code
- **RBAC minimal** : La managed identity a uniquement le rôle `Storage Blob Data Contributor` sur le resource group
- **Accès réseau restreint** : Storage, Key Vault et Cognitive Service n'acceptent que le trafic du subnet VNet
- **Pas d'accès public** : `public_network_access_enabled = false` sur tous les services sensibles
- **TLS 1.2** minimum sur le Storage Account

## Coût estimé (env dev, région West Europe)

| Service | Coût estimé/mois |
|---|---|
| Azure Functions (Consumption) | ~0€ (1M exécutions gratuites) |
| Azure Blob Storage (10 Go) | ~0.18€ |
| Azure AI Vision (S1, 1000 transactions) | ~1.50€ |
| Key Vault (Standard, <10k ops) | ~0.03€ |
| Application Insights (< 5 Go logs) | ~0€ (5 Go gratuits) |
| Log Analytics | ~0€ (< 5 Go) |
| **Total estimé** | **~2€/mois** |

> En production, prévoir Storage GRS (~2x), purge protection Key Vault, et surveiller le volume d'appels Vision.

## Convention de nommage

```
{type-ressource}-{projet}-{environnement}-{suffix}
ex: func-ocr-dev-abc123
    kv-ocr-prod-xyz789
    st{projet}{env}{suffix}  (storage account, sans tirets, max 24 chars)
```

## Pipeline CI/CD (GitHub Actions)

- `push` sur `develop` → validate + plan + deploy dev
- `pull_request` vers `main` → validate + plan (commentaire sur la PR)
- `push` sur `main` → validate + deploy prod (avec approval manuel requis)

Secrets GitHub à configurer :
```
AZURE_CLIENT_ID
AZURE_CLIENT_SECRET
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
```

## Auteurs

Groupe M2 Développement & Data — H3 Hitema 2026
