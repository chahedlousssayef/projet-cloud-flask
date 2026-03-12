# Guide pas à pas — Premier déploiement

Suivez les étapes dans l’ordre. Les valeurs à remplir sont indiquées entre `<>`.

---

## Étape 1 : Créer le dépôt GitHub et pousser le code

### 1.1 Initialiser Git et faire le premier commit (déjà fait si vous voyez ce fichier)

Dans le dossier du projet :

```bash
cd /Users/chahedloussayef/projet-cloud-flask
git init
git add .
git commit -m "Initial commit: Flask, Terraform, Ansible, GitHub Actions"
```

### 1.2 Créer le dépôt sur GitHub

1. Allez sur **https://github.com/new**
2. **Repository name** : `projet-cloud-flask`
3. **Visibility** : Public (ou Private si vous préférez)
4. Ne cochez **pas** "Add a README" (le projet en a déjà un)
5. Cliquez sur **Create repository**

### 1.3 Pousser le code

Sur la page du nouveau dépôt, GitHub affiche des commandes. Utilisez (en remplaçant `VOTRE-USERNAME` par votre identifiant GitHub) :

```bash
cd /Users/chahedloussayef/projet-cloud-flask
git remote add origin git@github.com:VOTRE-USERNAME/projet-cloud-flask.git
git branch -M main
git push -u origin main
```

Si on vous demande d’autoriser la clé SSH, acceptez. En cas d’erreur de permission, vérifiez que votre clé SSH est ajoutée à votre **compte** GitHub (Settings → SSH and GPG keys), pas seulement en deploy key.

---

## Étape 2 : Renseigner terraform.tfvars

### 2.1 Récupérer l’ID d’abonnement Azure

```bash
az login
az account show --query id -o tsv
```

Copiez la valeur affichée (UUID).

### 2.2 Éditer terraform.tfvars

Ouvrez le fichier :

```bash
cd /Users/chahedloussayef/projet-cloud-flask/infra/terraform
# Ouvrir terraform.tfvars dans l’éditeur
```

Modifiez **au minimum** ces 5 variables :

| Variable | Exemple / règle |
|----------|------------------|
| `subscription_id` | UUID copié à l’étape 2.1 (entre guillemets) |
| `admin_username` | Nom d’utilisateur Linux sur la VM (ex. `azureuser` ou votre prénom) |
| `storage_account_name` | **Unique dans tout Azure** : 3–24 caractères, minuscules et chiffres uniquement. Ex. `saflaskappcl2026` (vos initiales + année) |
| `postgres_password` | Mot de passe fort (entre guillemets) |
| `repo_url` | `git@github.com:VOTRE-USERNAME/projet-cloud-flask.git` (même URL que le remote) |

Exemple (à adapter) :

```hcl
subscription_id = "ea29641d-088d-483e-xxxx-xxxxxxxxxxxx"
admin_username   = "azureuser"
storage_account_name = "saflaskappcl2026"
postgres_password    = "MonMotDePasseSecurise123!"
repo_url    = "git@github.com:VOTRE-USERNAME/projet-cloud-flask.git"
```

Enregistrez le fichier. **Ne commitez pas** `terraform.tfvars` (il est dans `.gitignore`).

---

## Étape 3 : Ajouter la deploy key sur le dépôt

La VM a besoin de cloner le repo (et plus tard `git pull`). On utilise une **deploy key** = votre clé SSH publique, attachée au **dépôt** (pas au compte).

### 3.1 Copier votre clé publique

```bash
cat ~/.ssh/id_rsa.pub
```

Copiez toute la ligne (commence par `ssh-rsa ...`).

### 3.2 L’ajouter sur GitHub

1. Ouvrez votre dépôt : `https://github.com/VOTRE-USERNAME/projet-cloud-flask`
2. **Settings** → **Deploy keys** (menu de gauche)
3. **Add deploy key**
4. **Title** : `VM-deploy-key`
5. **Key** : collez la clé publique
6. Cochez **Allow write access**
7. **Add key**

---

## Étape 4 : Lancer Terraform (premier déploiement)

```bash
cd /Users/chahedloussayef/projet-cloud-flask/infra/terraform
terraform init
terraform plan
terraform apply
```

À la question `Do you want to perform these actions?`, tapez **yes**.

Attendez la fin (VM + Ansible, environ 5–10 min). En cas d’erreur, voir la section Dépannage du README.

À la fin, notez les sorties :

```bash
terraform output
```

Vous devez voir notamment : `vm_public_ip`, `ssh_command`, `flask_url`.

---

## Étape 5 : Configurer les secrets GitHub Actions

Pour que le workflow CI/CD se connecte en SSH à la VM, il faut trois secrets.

### 5.1 Où les ajouter

1. Dépôt **projet-cloud-flask** sur GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. **New repository secret**

### 5.2 Les trois secrets

| Nom du secret | Valeur |
|---------------|--------|
| `VM_HOST` | L’**IP publique** de la VM (sortie Terraform `vm_public_ip`, ou `terraform output -raw vm_public_ip`) |
| `VM_USERNAME` | La même valeur que `admin_username` dans `terraform.tfvars` |
| `VM_SSH_PRIVATE_KEY` | Le **contenu entier** de votre clé privée : `cat ~/.ssh/id_rsa` (tout le fichier, y compris les lignes `-----BEGIN ...` et `-----END ...`) |

Pour copier l’IP :

```bash
cd /Users/chahedloussayef/projet-cloud-flask/infra/terraform
terraform output -raw vm_public_ip
```

Pour copier la clé privée (affichage dans le terminal, puis copier-coller dans le secret) :

```bash
cat ~/.ssh/id_rsa
```

Créez les trois secrets un par un. Ne partagez jamais votre clé privée en dehors des secrets GitHub.

---

## Étape 6 : Vérifier

1. **App** : dans le navigateur ou avec curl :  
   `http://<VM_IP>:5000/health`  
   Réponse attendue : `{"status":"ok"}`

2. **CI/CD** : faites un petit changement (ex. dans ce fichier), commit + push sur `main`.  
   Onglet **Actions** du dépôt : le workflow "Deploy to Azure VM" doit se lancer et réussir.

---

## Récapitulatif des commandes (après avoir rempli terraform.tfvars)

```bash
cd /Users/chahedloussayef/projet-cloud-flask
git init
git add .
git commit -m "Initial commit: Flask, Terraform, Ansible, GitHub Actions"
# Créer le repo sur GitHub (interface web), puis :
git remote add origin git@github.com:VOTRE-USERNAME/projet-cloud-flask.git
git branch -M main
git push -u origin main

# Deploy key : Settings → Deploy keys → Add (coller ~/.ssh/id_rsa.pub, Allow write)

cd infra/terraform
terraform init
terraform plan
terraform apply   # yes

# Secrets Actions : Settings → Secrets and variables → Actions
# VM_HOST, VM_USERNAME, VM_SSH_PRIVATE_KEY
```

Vous pouvez garder ce fichier dans le repo pour vous aider les prochaines fois.
