#!/bin/bash
# Pilotage des stacks du devbox GPU.
# Usage : ./devbox.sh <up|down|logs|ps> [service...]   (sans service : tous)
set -e
ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
[ -f "$ROOT/.env" ] || { echo "Créer .env : cp .env.dist .env"; exit 1; }

# Ordre de démarrage (traefik et postgis d'abord)
ALL="traefik portainer postgis pgadmin redis opensearch keycloak redmine matomo geoserver"
CMD="${1:-up}"; shift || true
SERVICES="${*:-$ALL}"

docker network inspect devbox >/dev/null 2>&1 || docker network create devbox

compose() { local s=$1; shift; docker compose --env-file "$ROOT/.env" -f "$ROOT/$s/compose.yaml" "$@"; }

case "$CMD" in
  up)
    for s in $SERVICES; do
      compose "$s" up -d
      if [ "$s" = "postgis" ]; then
        until [ "$(docker inspect -f '{{.State.Health.Status}}' postgis)" = "healthy" ]; do sleep 2; done
        bash "$ROOT/postgis/create-databases.sh"
      fi
    done ;;
  down) for s in $(echo $SERVICES | tr ' ' '\n' | tac); do compose "$s" down; done ;;
  logs) for s in $SERVICES; do compose "$s" logs -f --tail 50; done ;;
  ps)   for s in $SERVICES; do compose "$s" ps; done ;;
  *) echo "Usage : $0 <up|down|logs|ps> [service...]"; exit 1 ;;
esac
