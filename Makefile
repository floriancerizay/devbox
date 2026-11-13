.PHONY: lint lint-sh lint-yaml lint-compose

lint: lint-sh lint-yaml lint-compose ## tous les contrôles

lint-sh: ## shellcheck sur les scripts
	shellcheck devbox.sh postgis/create-databases.sh traefik/mkcert/generate.sh

lint-yaml: ## yamllint sur les fichiers YAML
	yamllint .

lint-compose: ## validation de chaque compose avec .env.dist
	@for f in */compose.yaml; do \
	  docker compose --env-file .env.dist -f $$f --profile "*" config -q || exit 1; \
	done
