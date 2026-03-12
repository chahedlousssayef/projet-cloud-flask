#!/bin/bash
# Script de déploiement (utilisé par GitHub Actions et manuellement sur la VM)
set -e
cd "$(dirname "$0")"
git pull origin "${GIT_BRANCH:-main}"
docker compose -f infra/docker/compose.prod.yml --env-file .env up -d --build
