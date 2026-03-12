variable "subscription_id" {
  description = "ID de l'abonnement Azure"
  type        = string
}

variable "location" {
  description = "Région Azure (parmi: swedencentral, polandcentral, norwayeast, germanywestcentral, spaincentral)"
  type        = string
  default     = "germanywestcentral"
}

variable "resource_group_name" {
  description = "Nom du resource group"
  type        = string
  default     = "rg-flask-app"
}

variable "vm_name" {
  description = "Nom de la machine virtuelle"
  type        = string
  default     = "vm-flask-app"
}

variable "vm_size" {
  description = "Taille de la VM"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "admin_username" {
  description = "Nom d'utilisateur admin de la VM"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé SSH publique"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé SSH privée (pour Ansible)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Stockage Azure Blob
variable "storage_account_name" {
  description = "Nom du storage account (unique dans tout Azure, 3-24 caractères alphanumériques)"
  type        = string
}

variable "storage_container_name" {
  description = "Nom du container Blob pour les fichiers statiques"
  type        = string
  default     = "flask-files"
}

# Base de données PostgreSQL (sur la VM via Docker)
variable "postgres_user" {
  description = "Utilisateur PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "postgres_password" {
  description = "Mot de passe PostgreSQL"
  type        = string
  sensitive   = true
}

variable "postgres_db" {
  description = "Nom de la base de données"
  type        = string
  default     = "flaskapp"
}

variable "postgres_host" {
  description = "Host PostgreSQL (nom du service Docker)"
  type        = string
  default     = "postgres"
}

variable "postgres_port" {
  description = "Port PostgreSQL"
  type        = number
  default     = 5432
}

# Application
variable "flask_port" {
  description = "Port d'écoute de l'application Flask"
  type        = number
  default     = 5000
}

# Repo Git pour le déploiement
variable "repo_url" {
  description = "URL SSH du dépôt Git"
  type        = string
}

variable "repo_branch" {
  description = "Branche à déployer"
  type        = string
  default     = "main"
}
