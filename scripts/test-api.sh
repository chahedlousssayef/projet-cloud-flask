#!/usr/bin/env bash
# Script de test de l'API Flask après déploiement.
# Usage: ./scripts/test-api.sh [VM_IP]
#   ou:  VM_IP=1.2.3.4 ./scripts/test-api.sh
#   ou depuis infra/terraform: ./scripts/test-api.sh $(terraform output -raw vm_public_ip)

set -e

VM_IP="${1:-$VM_IP}"
if [ -z "$VM_IP" ]; then
  echo "Usage: $0 <VM_IP>" 1>&2
  echo "  ou:  VM_IP=1.2.3.4 $0" 1>&2
  echo "  ou depuis infra/terraform: $0 \$(terraform output -raw vm_public_ip)" 1>&2
  exit 1
fi

BASE_URL="http://${VM_IP}:5000"
echo "=== Test API Flask @ $BASE_URL ==="

# 1. Health
echo -n "GET /health ... "
resp=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
if [ "$resp" = "200" ]; then
  echo "OK ($resp)"
else
  echo "ÉCHEC (HTTP $resp)" 1>&2
  exit 1
fi

body=$(curl -s "$BASE_URL/health")
if echo "$body" | grep -q '"status":"ok"'; then
  echo "  -> $body"
else
  echo "  Réponse inattendue: $body" 1>&2
  exit 1
fi

# 2. CRUD rapide : créer un item
echo -n "POST /api/items ... "
create=$(curl -s -X POST "$BASE_URL/api/items" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test script", "description": "Créé par test-api.sh"}')
if echo "$create" | grep -q '"id"'; then
  id=$(echo "$create" | tr -d '\n' | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
  echo "OK (id=$id)"
else
  echo "ÉCHEC: $create" 1>&2
  exit 1
fi

# 3. Lister les items
echo -n "GET /api/items ... "
list=$(curl -s "$BASE_URL/api/items")
if echo "$list" | grep -q '"id"'; then
  echo "OK"
else
  echo "Réponse: $list" 1>&2
fi

# 4. Détail item
echo -n "GET /api/items/$id ... "
detail=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/items/$id")
if [ "$detail" = "200" ]; then
  echo "OK ($detail)"
else
  echo "HTTP $detail" 1>&2
fi

# 5. Supprimer l'item de test
echo -n "DELETE /api/items/$id ... "
del=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/api/items/$id")
if [ "$del" = "204" ]; then
  echo "OK ($del)"
else
  echo "HTTP $del" 1>&2
fi

echo "=== Tous les tests sont passés. ==="
