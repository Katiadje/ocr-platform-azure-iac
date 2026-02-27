# OCR Platform Azure - Terraform IaC

Projet M2 - Infrastructure as Code & IA  
Déploiement d'une plateforme d'extraction de texte d'images sur Azure avec Terraform

**Équipe :** Katia Djellali / Hadil / Lydia  
**Promo :** M2 IA & Data Systems - H3 Hitema

---

## C'est quoi le projet ?

L'idée c'est de déployer toute une infra Azure via Terraform (IaC) qui permet d'uploader une image, d'extraire le texte automatiquement avec Azure AI Vision, et de sauvegarder le résultat en JSON dans un blob storage.

Tout est provisionné en code, rien n'est créé à la main sur le portail Azure.

---

## Architecture

```
Utilisateur
    |
    | upload image (PNG/JPG)
    v
Azure Blob Storage (container: images-input)
    |
    | blob trigger
    v
Azure Function App (Python 3.11)
    |
    | appel API REST
    v
Azure AI Vision (OCR v3.2)
    |
    | résultat JSON
    v
Azure Blob Storage (container: ocr-results)
```

### Schéma des ressources déployées

```
Resource Group: rg-ocr-dev-cgh64f (France Central)
│
├── Réseau
│   ├── vnet-ocr-dev-cgh64f (10.0.0.0/16)
│   │   ├── snet-functions-ocr-dev (10.0.1.0/24)
│   │   └── snet-services-ocr-dev (10.0.2.0/24)
│   └── nsg-ocr-dev-cgh64f
│
├── Stockage
│   ├── stocrdevcgh64f (images-input / ocr-results)
│   └── stfuncocrdevcgh64f (dédié Azure Functions)
│
├── Compute
│   ├── asp-ocr-dev-cgh64f (Consumption Y1 - Linux)
│   └── func-ocr-dev-cgh64f (Python 3.11)
│
├── IA
│   └── cog-vision-ocr-dev-cgh64f (ComputerVision S1)
│
├── Sécurité
│   └── kv-ocr-dev-cgh64f (Key Vault Standard)
│
└── Monitoring
    ├── log-ocr-dev-cgh64f (Log Analytics)
    └── appi-ocr-dev-cgh64f (Application Insights)
```

### Stack technique

| Composant | Technologie |
|-----------|-------------|
| IaC | Terraform >= 1.3, provider azurerm ~3.80 |
| Compute | Azure Functions Y1, Python 3.11 |
| OCR / IA | Azure AI Vision S1 (v3.2) |
| Stockage | Azure Blob Storage LRS |
| Sécurité | Key Vault Standard + Managed Identity |
| Monitoring | Application Insights + Log Analytics |
| CI/CD | GitHub Actions |

---

## Structure du projet

```
ocr-platform-azure-iac/
│
├── main.tf                  # config principale, appel des modules
├── variables.tf             # variables globales
├── outputs.tf               # outputs du projet
├── terraform.tfvars         # valeurs des variables (gitignore en prod)
├── backend.tf               # backend distant Azure Storage
├── deploy.sh                # script de déploiement automatisé
│
├── modules/
│   ├── network/             # VNet, Subnet, NSG
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/             # Storage Accounts + containers
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cognitive_service/   # Azure AI Vision + Key Vault
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/             # Function App + App Service Plan
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/          # App Insights + Log Analytics + alertes
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── function/
│   └── ocr_function/
│       ├── __init__.py      # code Python de la function
│       ├── function.json    # config blob trigger
│       └── requirements.txt
│
└── .github/
    └── workflows/
        └── terraform.yml    # pipeline CI/CD
```

---

## Comment déployer

### Prérequis

- Terraform >= 1.3 installé
- Azure CLI installé et connecté (`az login`)
- Python 3.11 (pour la function)
- Un compte Azure actif

### Déploiement rapide (script automatisé)

```bash
chmod +x deploy.sh
./deploy.sh
```

Le script fait tout dans l'ordre : init, plan, apply, puis déploie la function.

### Déploiement manuel étape par étape

```bash
# 1. Initialiser Terraform avec le backend distant
terraform init

# 2. Vérifier ce qui va être créé
terraform plan

# 3. Déployer l'infrastructure
terraform apply -auto-approve

# 4. Déployer le code de la function
cd function
func azure functionapp publish func-ocr-dev-cgh64f --python
```

### Variables importantes

Créer un fichier `terraform.tfvars` :

```hcl
environment    = "dev"
location       = "francecentral"
project_name   = "ocr"
team_suffix    = "cgh64f"
```

> ⚠️ Ne jamais commiter les clés API ou les secrets dans le repo. Ils sont gérés via Key Vault.

---

## Sécurité

On a essayé de respecter le principe du moindre privilège et de ne pas laisser de ressources exposées inutilement.

### Ce qu'on a mis en place

**Managed Identity**  
La Function App utilise une identité managée system-assigned. Elle n'a pas besoin de stocker des credentials en dur pour accéder au Key Vault ou au Blob Storage.

**Key Vault**  
- La clé API Azure AI Vision est stockée dans le Key Vault, pas en clair dans les app settings
- Network rules : `defaultAction = Deny`, seuls le subnet functions et les IPs autorisées peuvent y accéder
- Soft delete activé (7 jours)

**Storage Account**  
- `public_network_access = true` (obligatoire pour le plan Consumption, cf. section limitations)
- `allow_nested_items_to_be_public = false`
- TLS 1.2 minimum
- Network rule pour le subnet functions

**RBAC**  
- La Managed Identity a le rôle `Storage Blob Data Contributor` sur le resource group
- Principe du moindre privilège : uniquement les permissions nécessaires

**Azure AI Vision**  
- `network_acls defaultAction = Deny`
- Accès autorisé uniquement depuis le subnet functions

### Limitations rencontrées

**Blob Trigger sur plan Consumption avec réseau restreint**  
Le plan Consumption utilise un mécanisme de polling sur des queues internes du storage account. Avec `defaultAction = Deny`, Azure Functions ne peut pas créer ces queues internes, ce qui empêche le trigger de fonctionner correctement.

Solution de contournement implémentée : appel direct à l'API Azure AI Vision via des bytes (sans passer par l'URL signée qui posait des problèmes de réseau). L'OCR fonctionne et a été testé avec succès.

En production réelle, on utiliserait un plan Premium EP1 qui supporte l'intégration VNet complète et résoudrait ce problème.

**Service Principal (CI/CD)**  
La création d'un Service Principal nécessite des droits Azure AD. Sur un compte Azure for Students, ces droits ne sont pas disponibles (`Insufficient privileges`). Le pipeline CI/CD est fonctionnel côté code mais les secrets GitHub ne peuvent pas être alimentés avec un vrai SP.

---

## Observabilité

**Application Insights** est connecté à la Function App via `APPINSIGHTS_INSTRUMENTATIONKEY`.

On peut voir dans le portail Azure :
- Les appels à la function (succès / erreurs)
- Les temps de réponse
- Les logs structurés de chaque analyse OCR

**Log Analytics Workspace** centralise tous les logs des ressources.

**Alerte configurée** : si la function génère plus de 5 erreurs en 5 minutes, une alerte se déclenche (metric alert sur Application Insights).

Pour accéder au dashboard : portail Azure → Application Insights → `appi-ocr-dev-cgh64f` → Vue d'ensemble

---

## Coût estimé

Environnement de développement (usage léger) :

| Service | SKU | Coût/mois estimé |
|---------|-----|-----------------|
| Azure Functions | Consumption Y1 | ~0€ (< 1M exécutions gratuites) |
| Blob Storage | Standard LRS | ~0.18€ (10 GB) |
| Azure AI Vision | S1 | ~1.50€ (1000 transactions) |
| Key Vault | Standard | ~0.03€ (< 10k opérations) |
| Application Insights | Pay-per-use | ~0€ (< 5 GB logs) |
| Log Analytics | Pay-per-use | ~0€ (< 5 GB/mois) |
| **Total estimé** | | **~2€/mois** |

> Note : ces estimations sont pour un usage dev/test. En production avec du volume, le poste principal serait Azure AI Vision (à ~1.50€ pour 1000 transactions OCR).

---

## Démonstration OCR

Preuve que l'OCR fonctionne — test effectué avec une image PNG contenant du texte en français :

```powershell
# Upload d'une image
az storage blob upload `
  --account-name stocrdevcgh64f `
  --container-name images-input `
  --name test.png `
  --file "C:\Users\katia\OneDrive\Bureau\test.png"

# Appel direct API Vision (avec les bytes de l'image)
$imageBytes = [System.IO.File]::ReadAllBytes("C:\Users\katia\OneDrive\Bureau\test.png")
Invoke-RestMethod `
  -Uri "https://cog-vision-ocr-dev-cgh64f.cognitiveservices.azure.com/vision/v3.2/ocr?language=fr&detectOrientation=true" `
  -Method POST `
  -Headers @{ "Ocp-Apim-Subscription-Key" = $env:VISION_KEY; "Content-Type" = "application/octet-stream" } `
  -Body $imageBytes
```

Résultat retourné (extrait) :
```json
{
  "language": "fr",
  "orientation": "Up",
  "textAngle": 0.0,
  "regions": [
    {
      "lines": [
        { "words": [{"text": "Le"}, {"text": "début"}] },
        { "words": [{"text": "Il"}, {"text": "y"}, {"text": "a"}, {"text": "3"}, {"text": "boîtes"}] }
      ]
    }
  ],
  "modelVersion": "2021-04-01"
}
```

---

## CI/CD Pipeline

Le fichier `.github/workflows/terraform.yml` contient 4 jobs :

1. `terraform-validate` : format check + validate (déclenché sur tous les push)
2. `terraform-plan` : génère le plan et le poste en commentaire sur les PR
3. `terraform-deploy-dev` : apply automatique sur push vers `develop`
4. `terraform-deploy-prod` : apply avec approbation manuelle sur push vers `main`

Secrets GitHub nécessaires :
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID` : 3ffed075-139d-4675-aeb8-e00e17e6100a
- `AZURE_TENANT_ID` : b411b782-6223-4f57-86f8-97a8366a74ea

---

## Ressources déployées (résumé)

| Ressource | Nom |
|-----------|-----|
| Resource Group | rg-ocr-dev-cgh64f |
| Virtual Network | vnet-ocr-dev-cgh64f |
| Subnet Functions | snet-functions-ocr-dev |
| Storage principal | stocrdevcgh64f |
| Storage functions | stfuncocrdevcgh64f |
| Container images | images-input |
| Container résultats | ocr-results |
| Cognitive Service | cog-vision-ocr-dev-cgh64f |
| Key Vault | kv-ocr-dev-cgh64f |
| Function App | func-ocr-dev-cgh64f |
| App Service Plan | asp-ocr-dev-cgh64f |
| Log Analytics | log-ocr-dev-cgh64f |
| Application Insights | appi-ocr-dev-cgh64f |