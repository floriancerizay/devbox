#!/bin/bash
# Crée (idempotent) les bases gpu-site, redmine et keycloak, avec l'extension postgis pour gpu-site.
# Usage : bash postgis/create-databases.sh  (depuis la racine, .env chargé)
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_FILE="${SCRIPT_DIR}/../.env"
# Lecture sans "source" : les mots de passe peuvent contenir $, # ou des espaces
env_get() { grep -E "^$1=" "${ENV_FILE}" | tail -n1 | cut -d= -f2-; }
POSTGRES_USER=$(env_get POSTGRES_USER)
GPU_SITE_DB=$(env_get GPU_SITE_DB)
REDMINE_DB=$(env_get REDMINE_DB)
KEYCLOAK_DB=$(env_get KEYCLOAK_DB)

psql_exec() { docker exec -i postgis psql -U "${POSTGRES_USER}" -d postgres -v ON_ERROR_STOP=1 "$@"; }

for db in "${GPU_SITE_DB}" "${REDMINE_DB}" "${KEYCLOAK_DB}"; do
    if [ "$(psql_exec -tAc "SELECT 1 FROM pg_database WHERE datname='${db}'")" != "1" ]; then
        echo "Création de la base ${db} ..."
        psql_exec -c "CREATE DATABASE \"${db}\""
    else
        echo "Base ${db} déjà présente"
    fi
done
docker exec -i postgis psql -U "${POSTGRES_USER}" -d "${GPU_SITE_DB}" -c "CREATE EXTENSION IF NOT EXISTS postgis"
