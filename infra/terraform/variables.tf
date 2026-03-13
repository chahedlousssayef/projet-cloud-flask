variable "subscription_id" {
  description = "ID de l'abonnement Azure"
  type        = string
}

variable "location" {
  description = "Region Azure"
  type        = string
  default     = "swedencentral"
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
  description = "Chemin vers la cle SSH publique"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la cle SSH privee"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "storage_account_name" {
  description = "Nom du storage account (unique dans tout Azure, 3-24 caracteres alphanumeriques)"
  type        = string
}

variable "storage_container_name" {
  description = "Nom du container Blob"
  type        = string
  default     = "flask-files"
}

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
  description = "Nom de la base de donnees"
  type        = string
  default     = "flaskapp"
}

variable "postgres_host" {
  description = "Host PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "postgres_port" {
  description = "Port PostgreSQL"
  type        = number
  default     = 5432
}

variable "flask_port" {
  description = "Port de l'application Flask"
  type        = number
  default     = 5000
}

variable "repo_url" {
  description = "URL du depot Git (HTTPS pour repo public, SSH pour repo prive)"
  type        = string
}

variable "repo_branch" {
  description = "Branche a deployer"
  type        = string
  default     = "main"
}
