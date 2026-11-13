# devbox GPU

Environnement de développement local pour le Géoportail de l'Urbanisme, inspiré de
[mborne/docker-devbox](https://github.com/mborne/docker-devbox) : un dossier par service,
un réseau docker partagé `devbox` et [traefik](traefik) pour exposer les UI en `*.dev.localhost`.

| Service | URL / port | Notes |
|---|---|---|
| traefik | https://traefik.dev.localhost:8443 | reverse proxy, dashboard |
| portainer | https://portainer.dev.localhost:8443 | UI docker ; compte `admin` / `PORTAINER_ADMIN_PASSWORD` créé au premier démarrage |
| postgis | 127.0.0.1:5433 | PostgreSQL 15 / PostGIS 3.3 ; bases `gpu-site`, `redmine`, `keycloak` |
| pgadmin | https://pgadmin.dev.localhost:8443 | UI PostgreSQL, sans login, serveur `postgis` préconfiguré (mot de passe : `POSTGRES_PASSWORD`) |
| redis | 127.0.0.1:6379 | mot de passe `REDIS_PASSWORD` |
| opensearch | http://os.dev.localhost:8080, 127.0.0.1:9200 | sécurité désactivée ; dashboards : `docker compose --profile dashboards` (os-dashboard.dev.localhost) |
| keycloak | https://keycloak.dev.localhost:8443 | mode `start-dev`, base sur postgis |
| redmine | https://redmine.dev.localhost:8443 | base sur postgis (admin/admin au premier démarrage) |
| matomo | https://matomo.dev.localhost:8443 | MariaDB dédiée (`matomo-db`) ; hôte BDD à saisir dans l'installeur : `matomo-db` |
| geoserver | https://geoserver.dev.localhost:8443/geoserver | image kartoza |

## Démarrage

```bash
cp .env.dist .env        # adapter les mots de passe, DOCKERHUB_PROXY (miroir IGN)
./devbox.sh up           # tous les services (traefik, postgis + création des bases, ...)
./devbox.sh up postgis redis opensearch   # ou seulement certains services
./devbox.sh up core      # groupe minimal : traefik postgis redis opensearch
./devbox.sh ps | down | restart redmine | pull
./devbox.sh reset redmine   # supprime conteneur + volumes (confirmation demandée)
./devbox.sh logs redmine   # un seul service à la fois
```

Traefik publie les ports **8080 (HTTP) / 8443 (HTTPS)** car apache2 occupe 80/443 sur l'hôte (`TRAEFIK_HTTP_PORT` / `TRAEFIK_HTTPS_PORT` dans `.env` ; 80/443 si libres, ce qui retire le port des URLs). Les ports de traefik sont liés à `127.0.0.1` (`DEVBOX_PORT_PREFIX`) : vider cette variable pour exposer le devbox sur le réseau. `up` démarre automatiquement postgis pour pgadmin, keycloak et redmine. Sans mkcert, traefik sert un certificat auto-signé.

`*.localhost` est résolu en local par les navigateurs et systemd-resolved. HTTPS (optionnel) :
`mkcert -install && bash traefik/mkcert/generate.sh`.

## Identifiants par défaut

Les mots de passe sont ceux de `.env` (valeurs `ChangeIt` dans `.env.dist`).

| Service | Identifiant | Mot de passe |
|---|---|---|
| portainer | `admin` | `PORTAINER_ADMIN_PASSWORD` |
| keycloak | `KEYCLOAK_ADMIN` | `KEYCLOAK_ADMIN_PASSWORD` |
| geoserver | `GEOSERVER_ADMIN_USER` | `GEOSERVER_ADMIN_PASSWORD` |
| redmine | `admin` | `admin` (à changer au premier login) |
| postgis | `POSTGRES_USER` | `POSTGRES_PASSWORD` |
| redis | – | `REDIS_PASSWORD` |
| pgadmin, opensearch | aucun | aucun |

## Mémoire utilisée

Mesure au repos, tous services démarrés : environ **3 Go** (opensearch ~1,3 Go, geoserver ~0,6 Go,
keycloak ~0,4 Go, les autres moins de 150 Mo chacun). Pour économiser, démarrer seulement
`./devbox.sh up core`.

## Utilisation avec gpu-site

Depuis un conteneur sur le réseau `devbox` (ajouter `networks: default: {name: devbox, external: true}`
au compose de gpu-site) :

```
PGHOST=postgis  PGUSER=postgis  PGDATABASE=gpu-site
REDIS_HOST=redis  REDIS_PORT=6379
OPENSEARCH_URL=http://opensearch:9200
```

Depuis l'hôte : `127.0.0.1`, postgis sur le port **5433** (`POSTGIS_PORT`), redis 6379, opensearch 9200.

## Notes

* Proxy sortant IGN : renseigner `DOCKERHUB_PROXY` (avec `/` final) pour tirer les images via le miroir.
* Redmine : créer le projet défini par `redmine.project` (`pole-assistance-gpu-dev`) pour gpu-site.
* Matomo en HTTP derrière traefik : si besoin, ajouter `trusted_hosts[]` / `force_ssl` dans `config.ini.php`.
* Volumes nommés : `./devbox.sh reset <service>` pour repartir de zéro (ou `docker volume ls` / `docker volume rm`).

## Dépannage

| Problème | Solution |
|---|---|
| Port déjà utilisé | Changer le port dans `.env` (`TRAEFIK_HTTPS_PORT`, `POSTGIS_PORT`, ...) puis relancer `up`. |
| opensearch s'arrête au démarrage | `sudo sysctl -w vm.max_map_count=262144` |
| `*.dev.localhost` ne répond pas | Vérifier que traefik tourne (`./devbox.sh ps traefik`) et utiliser le port `8443`. |
| postgis pas healthy | `./devbox.sh logs postgis` ; en dernier recours `./devbox.sh reset postgis`. |
| Avertissement de certificat | Normal sans mkcert (voir ci-dessus). Pour le retirer : `mkcert -uninstall`. |
| Portainer / traefik ne lisent pas le socket docker | Installation docker avec `userns-remap` : déjà géré par `userns_mode: host`. |
