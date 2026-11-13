#!/bin/bash
# Pilotage des stacks du devbox GPU.
# Usage : ./devbox.sh <up|down|restart|pull|logs|ps|reset> [service...]
#   sans service : tous (reset exige un service) ; "core" = traefik postgis redis opensearch
set -e
ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
[ -f "$ROOT/.env" ] || { echo "Créer .env : cp .env.dist .env"; exit 1; }

# Ordre de démarrage (traefik et postgis d'abord)
ALL="traefik portainer postgis pgadmin redis opensearch keycloak redmine matomo geoserver"
# Services qui ont besoin de la base postgis
NEEDS_POSTGIS=" pgadmin keycloak redmine "
POSTGIS_TIMEOUT=120
CORE="traefik postgis redis opensearch"
CMD="${1:-up}"; shift || true
ARGS="${*:-$ALL}"
# Développe les groupes (core) en liste de services
SERVICES=""
for a in $ARGS; do
  [ "$a" = "core" ] && a="$CORE"
  SERVICES="$SERVICES $a"
done
SERVICES="${SERVICES# }"

for s in $SERVICES; do
  [ -f "$ROOT/$s/compose.yaml" ] || { echo "Service inconnu : $s (disponibles : $ALL)"; exit 1; }
done

docker network inspect devbox >/dev/null 2>&1 || docker network create devbox

compose() { local s=$1; shift; docker compose --env-file "$ROOT/.env" -f "$ROOT/$s/compose.yaml" "$@"; }

postgis_status() { docker inspect -f '{{.State.Health.Status}}' postgis 2>/dev/null || echo absent; }

# Démarre postgis si besoin, attend qu'il soit healthy (avec timeout) et crée les bases
ensure_postgis() {
  [ "$(postgis_status)" = "healthy" ] && return 0
  compose postgis up -d
  local waited=0
  until [ "$(postgis_status)" = "healthy" ]; do
    if [ "$waited" -ge "$POSTGIS_TIMEOUT" ]; then
      echo "postgis n'est pas healthy après ${POSTGIS_TIMEOUT}s (statut : $(postgis_status))." >&2
      echo "Voir : ./devbox.sh logs postgis" >&2
      exit 1
    fi
    sleep 2; waited=$((waited + 2))
  done
  bash "$ROOT/postgis/create-databases.sh"
}

case "$CMD" in
  up)
    # Mots de passe laissés à la valeur par défaut
    grep -qE '^[A-Z_]*PASSWORD=ChangeIt' "$ROOT/.env" && echo "Attention : des mots de passe .env valent encore 'ChangeIt'." >&2
    for s in $SERVICES; do
      if [ "$s" = "postgis" ] || [[ "$NEEDS_POSTGIS" == *" $s "* ]]; then ensure_postgis; fi
      [ "$s" = "postgis" ] || compose "$s" up -d
    done ;;
  restart) for s in $SERVICES; do compose "$s" restart; done ;;
  pull) for s in $SERVICES; do compose "$s" pull; done ;;
  reset)
    # Supprime conteneurs ET volumes nommés : repart de zéro
    if [ "$#" -eq 0 ]; then echo "reset : indiquer le(s) service(s) à réinitialiser"; exit 1; fi
    echo "Conteneurs et volumes qui seront supprimés pour : $SERVICES"
    [[ " $SERVICES " == *" postgis "* ]] && echo "(postgis : les bases gpu-site, redmine et keycloak seront perdues)"
    read -r -p "Confirmer ? [y/N] " ok
    [[ "$ok" =~ ^[yYoO]$ ]] || { echo "Annulé"; exit 1; }
    for s in $SERVICES; do compose "$s" --profile "*" down -v; done ;;
  down) for s in $(echo $SERVICES | tr ' ' '\n' | tac); do compose "$s" down; done ;;
  logs)
    if [ "$#" -ne 1 ]; then echo "logs : indiquer un seul service (ex : ./devbox.sh logs redmine)"; exit 1; fi
    compose "$1" logs -f --tail 50 ;;
  ps)   for s in $SERVICES; do compose "$s" ps; done ;;
  *) echo "Usage : $0 <up|down|restart|pull|logs|ps|reset> [service...]"; exit 1 ;;
esac
