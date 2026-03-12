# Rapport du projet — Déploiement automatisé Flask sur Azure

## 1. Introduction

- **Objectif** : Déployer une application web Flask sur une machine virtuelle Azure avec stockage Blob et base PostgreSQL, en automatisant l’infrastructure (Terraform), la configuration (Ansible) et le déploiement continu (GitHub Actions).
- **Périmètre** : VM Ubuntu, Blob Storage, PostgreSQL dans Docker, API Flask (CRUD + fichiers).

---

## 2. Étapes réalisées

### 2.1 Environnement Terraform

- **Fichiers** : `provider.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`.
- **Provider** : Azure (azurerm ~4.55).
- **Régions utilisées** : parmi swedencentral, polandcentral, norwayeast, germanywestcentral, spaincentral.

*[À compléter : capture d’écran de la structure des fichiers Terraform et/ou de `terraform init` / `terraform validate`.]*

### 2.2 Déploiement de l’infrastructure

- **VM** : Ubuntu 22.04, IP publique, NSG (SSH 22, Flask 5000).
- **Stockage** : Compte de stockage Azure + conteneur Blob pour les fichiers (images, etc.).
- **Base de données** : PostgreSQL 16 dans un conteneur Docker sur la VM.

*[À compléter : capture d’écran de `terraform plan` / `terraform apply` et des outputs.]*

### 2.3 Backend Flask

- **Technologie** : Flask, Gunicorn, connexion PostgreSQL, SDK Azure Blob.
- **Fonctionnalités** : CRUD sur des “items”, upload/download/suppression de fichiers dans Blob, métadonnées en base.

*[À compléter : capture d’écran d’un test API (curl ou Postman) : création d’item, liste, upload fichier.]*

### 2.4 Connexion au stockage et CRUD

- Lecture/écriture/suppression de fichiers dans Azure Blob.
- CRUD API (create, read, update, delete) avec métadonnées en base et lien vers le fichier (blob_path).

*[À compléter : capture du portail Azure montrant le conteneur Blob après un upload.]*

### 2.5 Automatisation (Terraform + Ansible)

- **Variables** : `variables.tf` + `terraform.tfvars` (valeurs sensibles).
- **Outputs** : IP publique, URL app, commande SSH.
- **Ansible** : rôles `common`, `docker`, `deploy-stack` (clone repo, génération `.env`, `docker compose`).

*[À compléter : capture d’écran du déploiement Ansible ou de la VM avec `docker ps`.]*

### 2.6 CI/CD — GitHub Actions

- **Workflow** : déclenché sur push sur `main`, connexion SSH à la VM, exécution de `./deploy.sh` (git pull + docker compose up).
- **Secrets** : `VM_HOST`, `VM_USERNAME`, `VM_SSH_PRIVATE_KEY`.

*[À compléter : capture d’écran de l’onglet Actions montrant un run réussi.]*

---

## 3. Tests effectués

- Accès à l’application via l’IP publique (port 5000).
- Vérification du stockage des fichiers dans le conteneur Blob.
- Tests des opérations CRUD via l’API (curl ou Postman).

*[À compléter : résumé des commandes de test et résultats.]*

---

## 4. Problèmes rencontrés et résolution

| Problème | Cause / analyse | Solution |
|----------|------------------|----------|
| *exemple : erreur Ansible “Permission denied”* | *Clé SSH non copiée ou mauvaise permission* | *Vérifier `ssh_private_key_path` et droits 0600 sur la clé* |
| *(à compléter)* | | |

---

## 5. Conclusion

- Synthèse des livrables (infra, app, CI/CD).
- Améliorations possibles (HTTPS, base managée Azure, monitoring).

---

*Rapport à compléter avec vos captures d’écran et commentaires après déploiement et tests.*
