# Tests manuels — API Flask (CRUD + Blob)

Exécuter ces commandes **depuis le répertoire `infra/terraform`** après un `terraform apply` réussi, ou en remplaçant `$VM_IP` par l’IP publique de la VM.

**Validation rapide** (depuis la racine du repo) :  
`./scripts/test-api.sh $(cd infra/terraform && terraform output -raw vm_public_ip)`  
Ce script vérifie le health check et enchaîne un cycle CRUD (création, liste, détail, suppression).

## 1. Définir l’IP de la VM

```bash
cd infra/terraform
export VM_IP=$(terraform output -raw vm_public_ip)
echo "VM IP: $VM_IP"
```

## 2. Santé de l’API

```bash
curl -s "http://$VM_IP:5000/health"
# Attendu : {"status":"ok"}
```

## 3. Page d’accueil (liste des endpoints)

```bash
curl -s "http://$VM_IP:5000/"
```

## 4. CRUD — Items

### Créer un item

```bash
curl -s -X POST "http://$VM_IP:5000/api/items" \
  -H "Content-Type: application/json" \
  -d '{"title": "Mon premier item", "description": "Description test"}'
```

Noter l’`id` retourné (ex. `1`) pour les commandes suivantes.

### Lister tous les items

```bash
curl -s "http://$VM_IP:5000/api/items"
```

### Détail d’un item (remplacer `1` par l’id)

```bash
curl -s "http://$VM_IP:5000/api/items/1"
```

### Modifier un item (PATCH)

```bash
curl -s -X PATCH "http://$VM_IP:5000/api/items/1" \
  -H "Content-Type: application/json" \
  -d '{"title": "Titre modifié", "description": "Nouvelle description"}'
```

## 5. Fichiers (Azure Blob)

### Upload d’un fichier (remplacer `1` par l’id de l’item, et le chemin du fichier)

```bash
curl -s -X POST "http://$VM_IP:5000/api/items/1/files" \
  -F "file=@./image.png"
```

### Télécharger un fichier

Après un upload, l’API retourne `blob_path` (ex. `items/1/abc123_image.png`). Pour télécharger :

```bash
# Remplacer ITEM_ID et BLOB_PATH par les valeurs réelles
curl -s -o downloaded.png "http://$VM_IP:5000/api/items/1/files/items%2F1%2Fabc123_image.png"
```

### Supprimer un fichier

```bash
curl -s -X DELETE "http://$VM_IP:5000/api/items/1/files/items%2F1%2Fabc123_image.png"
```

## 6. Supprimer un item (DELETE)

```bash
curl -s -X DELETE "http://$VM_IP:5000/api/items/1"
# Réponse attendue : 204 No Content
```

## 7. Vérification côté Azure

- **Blob Storage** : Portail Azure → Compte de stockage → Containers → `flask-files` → vérifier la présence des blobs sous `items/<id>/`.
- **VM** : `terraform output ssh_command` puis `docker ps` sur la VM pour confirmer que les conteneurs tournent.

## 8. Détruire l’infrastructure

```bash
cd infra/terraform
terraform destroy
# Confirmer par yes
```
