# Docker Services:
#   up - Start services (use: make up [service...] or make up MODE=prod, ARGS="--build" for options)
#   down - Stop services (use: make down [service...] or make down MODE=prod, ARGS="--volumes" for options)
#   build - Build containers (use: make build [service...] or make build MODE=prod)
#   logs - View logs (use: make logs [service] or make logs SERVICE=backend, MODE=prod for production)
#   restart - Restart services (use: make restart [service...] or make restart MODE=prod)
#   shell - Open shell in container (use: make shell [service] or make shell SERVICE=gateway, MODE=prod, default: backend)
#   ps - Show running containers (use MODE=prod for production)
#
# Convenience Aliases (Development):
#   dev-up - Alias: Start development environment
#   dev-down - Alias: Stop development environment
#   dev-build - Alias: Build development containers
#   dev-logs - Alias: View development logs
#   dev-restart - Alias: Restart development services
#   dev-shell - Alias: Open shell in backend container
#   dev-ps - Alias: Show running development containers
#   backend-shell - Alias: Open shell in backend container
#   gateway-shell - Alias: Open shell in gateway container
#   mongo-shell - Open MongoDB shell
#
# Convenience Aliases (Production):
#   prod-up - Alias: Start production environment
#   prod-down - Alias: Stop production environment
#   prod-build - Alias: Build production containers
#   prod-logs - Alias: View production logs
#   prod-restart - Alias: Restart production services
#
# Backend:
#   backend-build - Build backend TypeScript
#   backend-install - Install backend dependencies
#   backend-type-check - Type check backend code
#   backend-dev - Run backend in development mode (local, not Docker)
#
# Database:
#   db-reset - Reset MongoDB database (WARNING: deletes all data)
#   db-backup - Backup MongoDB database
#
# Cleanup:
#   clean - Remove containers and networks (both dev and prod)
#   clean-all - Remove containers, networks, volumes, and images
#   clean-volumes - Remove all volumes
#
# Utilities:
#   status - Alias for ps
#   health - Check service health
#
# Help:
#   help - Display this help message

.PHONY: help up down build logs restart shell ps clean clean-all clean-volumes status health \
        dev-up dev-down dev-build dev-logs dev-restart dev-shell dev-ps \
        prod-up prod-down prod-build prod-logs prod-restart \
        backend-shell gateway-shell mongo-shell \
        backend-build backend-install backend-type-check backend-dev \
        db-reset db-backup

# Default mode is development
MODE ?= dev
SERVICE ?= backend
ARGS ?=

# Compose file paths
DEV_COMPOSE = docker/compose.development.yaml
PROD_COMPOSE = docker/compose.production.yaml

# Select compose file based on MODE
ifeq ($(MODE),prod)
    COMPOSE_FILE = $(PROD_COMPOSE)
else
    COMPOSE_FILE = $(DEV_COMPOSE)
endif

# Docker compose command
DC = docker compose -f $(COMPOSE_FILE)

# =============================================================================
# Main Commands
# =============================================================================

help:
	@head -50 Makefile | grep -E '^#' | sed 's/^# //'

up:
	$(DC) up -d $(ARGS)

down:
	$(DC) down $(ARGS)

build:
	$(DC) build $(ARGS)

logs:
	$(DC) logs -f $(SERVICE)

restart:
	$(DC) restart $(ARGS)

shell:
	docker exec -it $(shell docker compose -f $(COMPOSE_FILE) ps -q $(SERVICE) | head -1) sh

ps:
	$(DC) ps

# =============================================================================
# Development Aliases
# =============================================================================

dev-up:
	@$(MAKE) up MODE=dev

dev-down:
	@$(MAKE) down MODE=dev

dev-build:
	@$(MAKE) build MODE=dev

dev-logs:
	@$(MAKE) logs MODE=dev SERVICE=$(SERVICE)

dev-restart:
	@$(MAKE) restart MODE=dev

dev-shell:
	@$(MAKE) shell MODE=dev SERVICE=backend

dev-ps:
	@$(MAKE) ps MODE=dev

# =============================================================================
# Production Aliases
# =============================================================================

prod-up:
	@$(MAKE) up MODE=prod

prod-down:
	@$(MAKE) down MODE=prod

prod-build:
	@$(MAKE) build MODE=prod

prod-logs:
	@$(MAKE) logs MODE=prod SERVICE=$(SERVICE)

prod-restart:
	@$(MAKE) restart MODE=prod

# =============================================================================
# Service Shell Shortcuts
# =============================================================================

backend-shell:
	@$(MAKE) shell SERVICE=backend

gateway-shell:
	@$(MAKE) shell SERVICE=gateway

mongo-shell:
ifeq ($(MODE),prod)
	docker exec -it mongodb mongosh -u admin -p password123
else
	docker exec -it mongodb-dev mongosh -u admin -p password123
endif

# =============================================================================
# Backend Commands (Local Development)
# =============================================================================

backend-build:
	cd backend && npm run build

backend-install:
	cd backend && npm install

backend-type-check:
	cd backend && npm run type-check

backend-dev:
	cd backend && npm run dev

# =============================================================================
# Database Commands
# =============================================================================

db-reset:
	@echo "WARNING: This will delete all data in MongoDB!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
ifeq ($(MODE),prod)
	docker compose -f $(PROD_COMPOSE) down -v
	docker volume rm cuet-cse-fest-devops-hackathon-preli_mongo_data 2>/dev/null || true
else
	docker compose -f $(DEV_COMPOSE) down -v
	docker volume rm cuet-cse-fest-devops-hackathon-preli_mongo_data_dev 2>/dev/null || true
endif

db-backup:
	@mkdir -p backups
ifeq ($(MODE),prod)
	docker exec mongodb mongodump --uri="mongodb://admin:password123@localhost:27017" --out=/tmp/backup
	docker cp mongodb:/tmp/backup ./backups/backup-$(shell date +%Y%m%d-%H%M%S)
else
	docker exec mongodb-dev mongodump --uri="mongodb://admin:password123@localhost:27017" --out=/tmp/backup
	docker cp mongodb-dev:/tmp/backup ./backups/backup-$(shell date +%Y%m%d-%H%M%S)
endif
	@echo "Backup saved to ./backups/"

# =============================================================================
# Cleanup Commands
# =============================================================================

clean:
	docker compose -f $(DEV_COMPOSE) down --remove-orphans 2>/dev/null || true
	docker compose -f $(PROD_COMPOSE) down --remove-orphans 2>/dev/null || true

clean-all:
	docker compose -f $(DEV_COMPOSE) down --rmi all --volumes --remove-orphans 2>/dev/null || true
	docker compose -f $(PROD_COMPOSE) down --rmi all --volumes --remove-orphans 2>/dev/null || true

clean-volumes:
	docker compose -f $(DEV_COMPOSE) down -v 2>/dev/null || true
	docker compose -f $(PROD_COMPOSE) down -v 2>/dev/null || true

# =============================================================================
# Utility Commands
# =============================================================================

status: ps

health:
ifeq ($(MODE),prod)
	@echo "Checking production health..."
	@curl -s http://localhost:5921/health || echo "Gateway not responding"
else
	@echo "Checking development health..."
	@curl -s http://localhost:5921/health || echo "Gateway not responding"
	@curl -s http://localhost:3847/api/health || echo "Backend not responding"
endif

