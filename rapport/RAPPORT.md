# Rapport du projet — Déploiement automatisé Flask sur Azure

## 1. Introduction

- **Objectif** : Déployer une application web Flask sur une machine virtuelle Azure avec stockage Blob et base PostgreSQL, en automatisant l’infrastructure (Terraform), la configuration (Ansible) et le déploiement continu (GitHub Actions).
- **Périmètre** : VM Ubuntu 22.04, Azure Blob Storage, PostgreSQL 16 dans Docker, API Flask (CRUD + fichiers statiques : images, logs).

---

## 2. Étapes réalisées

### 2.1 Environnement Terraform

- **Fichiers** : `provider.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`.
- **Provider** : Azure (azurerm ~4.55), version Terraform >= 1.0.
- **Régions utilisées** : parmi `swedencentral`, `polandcentral`, `norwayeast`, `germanywestcentral`, `spaincentral`.

**Commandes à exécuter pour valider :**
```bash
cd infra/terraform
terraform init
terraform validate
```

*[À compléter : capture d’écran de la structure des fichiers Terraform et/ou de `terraform init` / `terraform validate`.]*

### 2.2 Déploiement de l’infrastructure

- **VM** : Ubuntu 22.04 LTS (Canonical), IP publique statique, NSG (SSH 22, HTTP 80, Flask 5000).
- **Stockage** : Compte de stockage Azure (Standard LRS, TLS 1.2) + conteneur Blob privé `flask-files` pour images, logs et fichiers applicatifs.
- **Base de données** : PostgreSQL 16 (Alpine) dans un conteneur Docker sur la VM, avec healthcheck.

**Commandes :** `terraform plan` puis `terraform apply` (confirmer par yes), puis `terraform output`.

*[À compléter : capture d’écran de `terraform plan` / `terraform apply` et des outputs.]*

### 2.3 Backend Flask

- **Technologie** : Flask, Gunicorn, connexion PostgreSQL, SDK Azure Blob.
- **Fonctionnalités** : CRUD sur des “items”, upload/download/suppression de fichiers dans Blob, métadonnées en base.

*[À compléter : capture d’écran d’un test API (curl ou Postman) : création d’item, liste, upload fichier.]*

### 2.4 Connexion au stockage et CRUD

- **Lecture/écriture/suppression** : le backend utilise `AZURE_STORAGE_CONNECTION_STRING` et `AZURE_STORAGE_CONTAINER_NAME` ; les fichiers sont stockés sous le préfixe `items/<id>/`. Conteneur en accès privé ; seules les requêtes API accèdent au stockage.

*[À compléter : capture du portail Azure (Storage account → Containers → flask-files) après un upload.]*

### 2.5 Automatisation (Terraform + Ansible)

- **Variables** : `variables.tf` pour la déclaration ; `terraform.tfvars` (non versionné) pour les valeurs sensibles.
- **Outputs** : `vm_public_ip`, `app_url`, `flask_url`, `ssh_command`, `storage_account_name`, `resource_group_name`.
- **Ansible** : après création de la VM, un `null_resource` lance `bootstrap.yml` puis `deploy.yml`. Rôles : `common`, `docker`, `deploy-stack` (clone repo, `.env`, `docker compose up`).

*[À compléter : capture d’écran du déploiement Ansible ou de la VM avec `docker ps`.]*

### 2.6 CI/CD — GitHub Actions

- **Workflow** : déclenché sur push sur `main`, connexion SSH à la VM, `cd ~/app && ./deploy.sh` (git pull + docker compose up -d --build).
- **Secrets** : `VM_HOST`, `VM_USERNAME`, `VM_SSH_PRIVATE_KEY`.

*[À compléter : capture d’écran de l’onglet Actions montrant un run réussi.]*

---

## 3. Tests effectués

### 3.1 Accès à l’application

```bash
export VM_IP=$(terraform output -raw vm_public_ip)   # depuis infra/terraform
curl -s "http://$VM_IP:5000/health"   # Attendu : {"status":"ok"}
```

### 3.2 CRUD et stockage

```bash
# Créer un item
curl -s -X POST "http://$VM_IP:5000/api/items" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "description": "Item test"}'

# Lister les items
curl -s "http://$VM_IP:5000/api/items"

# Upload d’un fichier (remplacer <ID> par l’id retourné)
curl -s -X POST "http://$VM_IP:5000/api/items/<ID>/files" -F "file=@/chemin/vers/image.png"
```

Vérifier dans le portail Azure que le conteneur `flask-files` contient un blob sous `items/<ID>/...`.

*[À compléter : résumé des résultats (réponses JSON, codes HTTP) et captures.]*

---

## 4. Problèmes rencontrés et résolution

| Problème | Cause / analyse | Solution |
|----------|------------------|----------|
| Ansible « Permission denied » (SSH) | Clé SSH non trouvée ou mauvaise permission | Vérifier ssh_private_key_path et chmod 0600 sur la clé privée |
| Clone Git échoue sur la VM | Deploy key absente ou sans accès en écriture | Ajouter la clé publique en Deploy key (Allow write access) |
| GitHub Actions échoue (SSH) | Secrets incorrects ou IP obsolète | Vérifier VM_HOST, VM_USERNAME, VM_SSH_PRIVATE_KEY |
| Quota ou SKU non disponible | Région ou taille de VM non disponible | Changer location ou vm_size dans terraform.tfvars |
| Blob « not configured » (503) | Variables Blob manquantes | Vérifier .env : AZURE_STORAGE_CONNECTION_STRING et AZURE_STORAGE_CONTAINER_NAME |

*[À compléter : problèmes spécifiques que vous avez rencontrés.]*

---

## 5. Conclusion

- **Livrables** : infrastructure Terraform (VM, réseau, Blob, NSG), backend Flask avec CRUD et Blob, PostgreSQL dans Docker, provisioning Ansible, CI/CD GitHub Actions.
- **Améliorations possibles** : HTTPS (reverse proxy + certificat), base managée Azure (Azure Database for PostgreSQL), monitoring (Azure Monitor, logs), sauvegarde du volume PostgreSQL.

---

## 6. Rendu du projet

### 6.1 Contenu du dépôt GitHub

- [ ] Code Terraform (`infra/terraform/*.tf`)
- [ ] README.md (installation et utilisation)
- [ ] Script de provisioning (Ansible : `infra/ansible/`)
- [ ] Code du backend et instructions (`services/backend/`, `deploy.sh`, `docs/TESTS.md`)
- [ ] Script de test : `scripts/test-api.sh` (validation health + CRUD après déploiement)

### 6.2 Captures d’écran à joindre dans le rapport

| # | Description | Où l’insérer |
|---|-------------|--------------|
| 1 | Structure des fichiers Terraform ou sortie de `terraform init` / `terraform validate` | § 2.1 |
| 2 | Sortie de `terraform plan` ou `terraform apply` (résumé) et `terraform output` | § 2.2 |
| 3 | Test API : création d’item, liste, upload fichier (curl ou Postman) | § 2.3 |
| 4 | Portail Azure : conteneur Blob `flask-files` avec un ou plusieurs blobs | § 2.4 |
| 5 | Déploiement Ansible (sortie playbook) ou `docker ps` sur la VM | § 2.5 |
| 6 | GitHub Actions : onglet Actions, run réussi du workflow « Deploy to Azure VM » | § 2.6 |

**Commande de validation automatique** (à exécuter après déploiement, depuis la racine du repo) :
```bash
./scripts/test-api.sh $(cd infra/terraform && terraform output -raw vm_public_ip)
```

---

*Rapport à compléter avec vos captures d’écran et commentaires après déploiement et tests.*
