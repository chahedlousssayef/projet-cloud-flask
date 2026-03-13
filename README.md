# Flask sur Azure — Terraform, Ansible, GitHub Actions

Application web **Flask** déployée sur **Microsoft Azure** : infrastructure avec **Terraform**, configuration avec **Ansible**, et déploiement continu via **GitHub Actions**.

## Architecture

```
Internet
   │
   ▼
Azure Public IP
   │
   ├── :22   → SSH
   ├── :5000 → Flask (API + CRUD + Azure Blob)
   │
   └── [VM Ubuntu 22.04 — Docker Compose]
         ├── backend (Flask + Gunicorn)
         └── postgres (PostgreSQL 16)

Azure Blob Storage ◄── backend (fichiers des items)
```

## Stack

| Composant     | Technologie                    |
|---------------|--------------------------------|
| Cloud         | Microsoft Azure                |
| IaC           | Terraform (AzureRM ~4.55)      |
| Provisioning  | Ansible 2.x                    |
| Backend       | Flask, PostgreSQL, Azure Blob |
| Conteneurs   | Docker + Docker Compose        |
| CI/CD         | GitHub Actions (SSH deploy)   |

## Prérequis

- **Azure CLI** : `brew install azure-cli` puis `az login`
- **Terraform** : `brew install terraform`
- **Ansible** : `brew install ansible`  
  Puis installer la collection Docker :  
  `ansible-galaxy collection install community.docker`
- **Clé SSH** : `~/.ssh/id_rsa` et `~/.ssh/id_rsa.pub`
- **Régions autorisées** : `swedencentral`, `polandcentral`, `norwayeast`, `germanywestcentral`, `spaincentral`

## Déploiement Azure (pas à pas)

### 1. Cloner le projet

```bash
git clone git@github.com:VOTRE-USERNAME/projet-cloud-flask.git
cd projet-cloud-flask
```

### 2. Connexion Azure

```bash
az login
az account show --query id -o tsv   # copier le subscription_id
```

### 3. Configurer Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Éditer `terraform.tfvars` et renseigner au minimum :

- `subscription_id` (UUID Azure)
- `location` : une parmi `swedencentral`, `polandcentral`, `norwayeast`, `germanywestcentral`, `spaincentral`
- `admin_username`
- `storage_account_name` (unique globalement, ex. `saflaskappvosinitiales2026`)
- `postgres_password`
- `repo_url` : `git@github.com:VOTRE-USERNAME/projet-cloud-flask.git`

### 4. Deploy key GitHub

Pour que la VM clone le repo, ajoutez votre clé publique en **Deploy key** (avec accès en écriture) :

- GitHub → Settings → Deploy keys → Add deploy key
- Coller le contenu de `~/.ssh/id_rsa.pub`

### 5. Lancer l’infrastructure

```bash
terraform init
terraform plan
terraform apply   # confirmer par yes
```

Terraform crée le resource group, le réseau, la VM, le Blob Storage, puis Ansible installe Docker, clone le repo, génère le `.env` et lance Docker Compose. Comptez environ 5 minutes.

### 6. Sorties Terraform

```bash
terraform output
```

- `app_url` / `flask_url` : accès à l’API
- `ssh_command` : connexion SSH à la VM

### 7. Configurer GitHub Actions (CI/CD)

Dans le dépôt GitHub → Settings → Secrets and variables → Actions, ajouter :

| Secret              | Valeur                    |
|---------------------|---------------------------|
| `VM_HOST`           | IP publique de la VM      |
| `VM_USERNAME`       | Valeur de `admin_username`|
| `VM_SSH_PRIVATE_KEY`| Contenu de `~/.ssh/id_rsa`|

À chaque push sur `main`, le workflow déploie sur la VM (SSH + `./deploy.sh`).

### 8. Tests

```bash
# Santé
curl http://$(terraform output -raw vm_public_ip):5000/health

# CRUD
curl -X POST http://$(terraform output -raw vm_public_ip):5000/api/items \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "description": "Item test"}'

curl http://$(terraform output -raw vm_public_ip):5000/api/items
```

### 9. Détruire l’infrastructure

```bash
terraform destroy
```

Répondre `yes` à la confirmation.

**Valider le déploiement** (depuis la racine du repo) :
```bash
./scripts/test-api.sh $(cd infra/terraform && terraform output -raw vm_public_ip)
```
Voir aussi **[docs/TESTS.md](docs/TESTS.md)** pour les commandes de test détaillées (CRUD, Blob, santé).

## Déploiement local (dev)

```bash
cp .env.example .env   # remplir PostgreSQL et optionnellement Azure Blob
docker compose -f infra/docker/compose.prod.yml up --build
# API : http://localhost:5000
```

## Endpoints API

| Méthode | Endpoint                      | Description        |
|---------|-------------------------------|--------------------|
| GET     | /health                       | Santé              |
| GET     | /api/items                    | Liste des items    |
| POST    | /api/items                    | Créer un item      |
| GET     | /api/items/:id                | Détail item        |
| PATCH   | /api/items/:id                | Modifier item      |
| DELETE  | /api/items/:id                | Supprimer item     |
| POST    | /api/items/:id/files          | Upload fichier     |
| GET     | /api/items/:id/files/:blob    | Télécharger fichier|
| DELETE  | /api/items/:id/files/:blob    | Supprimer fichier  |

## Structure du projet

```
/
├── services/backend/          # Flask (CRUD + Blob)
├── infra/
│   ├── terraform/             # VM, VNet, NSG, Blob Storage
│   ├── ansible/               # Bootstrap + déploiement (Docker, clone, compose)
│   └── docker/
│       └── compose.prod.yml    # Backend + PostgreSQL
├── .github/workflows/
│   └── deploy.yml             # CI/CD GitHub Actions
├── deploy.sh                  # Script de déploiement (VM + Actions)
├── docs/
│   └── TESTS.md               # Commandes de test manuelles (curl)
├── scripts/
│   └── test-api.sh            # Script de validation (health + CRUD)
├── .env.example
└── README.md
```

## Dépannage

- **Quota / Sku non disponible** : changer `location` ou `vm_size` dans `terraform.tfvars`.
- **Échec clone Git sur la VM** : vérifier la deploy key (écriture) et que la clé privée a bien été copiée par Ansible.
- **GitHub Actions échoue** : vérifier les secrets `VM_HOST`, `VM_USERNAME`, `VM_SSH_PRIVATE_KEY`.

## Licence

MIT
