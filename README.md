# Image Clock — Flask + Azure Blob Storage

Horloge web dont les chiffres peuvent etre remplaces par des images stockees sur **Azure Blob Storage**.

Un seul `terraform apply` cree toute l'infrastructure Azure, installe Docker sur la VM, et deploie l'application.

## Architecture

```
Internet
   |
   v
Azure VM (Ubuntu 22.04)
   |
   +-- :80   Nginx (frontend)  ---proxy /api/--->  Flask (backend)
   +-- :5000 Flask (API directe)  ------------->  PostgreSQL
   +-- :22   SSH                                  Azure Blob Storage
   |
   [Docker Compose : frontend + backend + postgres]
```

## Prerequis

Tous les outils doivent etre installes **sur votre machine locale** (pas sur la VM).

### macOS

```bash
brew install azure-cli terraform ansible
```

### Linux (Ubuntu/Debian)

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform

# Ansible
sudo apt-get install -y ansible
```

### Windows

Utiliser **WSL 2** (Windows Subsystem for Linux) puis suivre les instructions Linux ci-dessus.

```powershell
# Installer WSL (PowerShell en admin)
wsl --install
# Puis ouvrir le terminal Ubuntu et suivre les etapes Linux
```

### Cle SSH

Une paire de cles SSH **sans passphrase** est necessaire :

```bash
# Si vous n'avez pas de cle SSH ou si elle a une passphrase
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

> Verifiez que `~/.ssh/id_rsa` et `~/.ssh/id_rsa.pub` existent avant de continuer.

## Deploiement

### Etape 1 — Cloner le repo

```bash
git clone https://github.com/chahedlousssayef/projet-cloud-flask.git
cd projet-cloud-flask
```

### Etape 2 — Se connecter a Azure

```bash
az login
```

Notez votre **subscription ID** :

```bash
az account show --query id -o tsv
```

### Etape 3 — Configurer les variables Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Ouvrir `terraform.tfvars` dans un editeur et remplir :

| Variable               | Quoi mettre                                                    |
|------------------------|----------------------------------------------------------------|
| `subscription_id`      | L'UUID recupere a l'etape 2                                    |
| `admin_username`       | Un nom d'utilisateur pour la VM (ex: `azureuser`)              |
| `storage_account_name` | Un nom unique dans Azure, 3-24 caracteres, minuscules (ex: `saflaskjean2026`) |
| `postgres_password`    | Un mot de passe fort pour PostgreSQL                           |
| `repo_url`             | `https://github.com/chahedlousssayef/projet-cloud-flask.git`  |

Les autres variables ont des valeurs par defaut qui fonctionnent telles quelles.

> **Regions disponibles** : `swedencentral` (defaut), `polandcentral`, `norwayeast`, `germanywestcentral`, `spaincentral`

### Etape 4 — Deployer (terraform init / plan / apply)

```bash
terraform init    # Telecharge les providers Azure, time, local, null
terraform plan    # Affiche ce qui va etre cree (verification)
terraform apply   # Cree tout — confirmer par "yes"
```

Le deploiement prend environ **5 minutes**. Terraform va :
1. Creer les ressources Azure (Resource Group, VNet, NSG, IP, VM, Blob Storage)
2. Lancer Ansible automatiquement pour configurer la VM
3. Installer Docker et Docker Compose sur la VM
4. Cloner ce repo sur la VM
5. Generer le fichier `.env` de production
6. Lancer `docker compose` (frontend + backend + postgres)
7. Verifier que tout repond correctement

### Etape 5 — Recuperer les URLs

```bash
terraform output
```

Vous obtiendrez :

```
frontend_url        = "http://<IP>"          # Ouvrir dans le navigateur
api_url             = "http://<IP>:5000"     # API Flask directe
ssh_command         = "ssh <user>@<IP>"      # Connexion SSH a la VM
vm_public_ip        = "<IP>"
```

### Etape 6 — Tester

```bash
# Ouvrir le frontend dans le navigateur
open http://$(terraform output -raw vm_public_ip)         # macOS
xdg-open http://$(terraform output -raw vm_public_ip)     # Linux

# Tester l'API
curl http://$(terraform output -raw vm_public_ip):5000/health
# -> {"status":"ok"}

curl http://$(terraform output -raw vm_public_ip):5000/api/clock/digits
# -> liste des digits de l'horloge
```

### Detruire l'infrastructure

```bash
terraform destroy   # confirmer par "yes"
```

Cela supprime **toutes** les ressources Azure creees.

## Dev local (sans Azure)

```bash
cp .env.example .env    # remplir POSTGRES_PASSWORD et AZURE_STORAGE_CONNECTION_STRING
docker compose -f infra/docker/compose.prod.yml --env-file .env up --build
# Frontend : http://localhost
# API      : http://localhost:5000
```

## Endpoints API

| Methode | Endpoint                     | Description             |
|---------|------------------------------|-------------------------|
| GET     | /health                      | Sante                   |
| GET     | /api/items                   | Lister les items        |
| POST    | /api/items                   | Creer un item           |
| GET     | /api/items/:id               | Detail d'un item        |
| PATCH   | /api/items/:id               | Modifier un item        |
| DELETE  | /api/items/:id               | Supprimer un item       |
| POST    | /api/items/:id/files         | Upload fichier Blob     |
| GET     | /api/items/:id/files/:blob   | Telecharger fichier     |
| DELETE  | /api/items/:id/files/:blob   | Supprimer fichier       |
| GET     | /api/clock/digits            | Lister les digits       |
| POST    | /api/clock/digits/:d         | Upload image pour digit |
| GET     | /api/clock/digits/:d/image   | Recuperer image digit   |
| DELETE  | /api/clock/digits/:d         | Supprimer image digit   |

## Structure du projet

```
projet-cloud-flask/
+-- services/
|   +-- backend/            # Flask + Gunicorn
|   |   +-- app/routes.py   # Tous les endpoints
|   |   +-- Dockerfile
|   +-- frontend/           # Nginx + HTML/JS/CSS
|       +-- nginx.conf      # Reverse proxy /api/ -> backend
|       +-- Dockerfile
+-- infra/
|   +-- terraform/          # Infrastructure Azure
|   |   +-- main.tf         # Ressources + provisioner Ansible
|   |   +-- variables.tf    # Variables configurables
|   |   +-- outputs.tf      # URLs de sortie
|   +-- ansible/            # Configuration de la VM
|   |   +-- roles/common/   # Repertoires
|   |   +-- roles/docker/   # Installation Docker
|   |   +-- roles/deploy-stack/  # Clone + compose up
|   +-- docker/
|       +-- compose.prod.yml
+-- .env.example            # Template variables d'environnement
+-- terraform.tfvars.example # Template variables Terraform
```

## Depannage

| Probleme | Solution |
|----------|----------|
| `SkuNotAvailable` a l'apply | Changer `location` ou `vm_size` dans terraform.tfvars |
| `permission denied` docker | Relancer `terraform apply` (le reset_connection regle ca) |
| Postgres crash en boucle | Le `--env-file .env` est deja configure, verifier que .env est genere |
| Ansible timeout / unreachable | La VM met ~30s a demarrer, relancer `terraform taint null_resource.ansible && terraform apply` |
| Erreur SSH passphrase | Regenerer la cle : `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""` |
