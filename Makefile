.PHONY: help docker-build docker-up docker-down docker-restart docker-logs ssl-generate ssl-letsencrypt

help: ## Show this help message
	@echo "HabitChain Docker Deployment Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# SSL Certificate Management
ssl-generate: ## Generate self-signed SSL certificates for testing
	@echo "Generating self-signed SSL certificate..."
	@./scripts/generate-ssl-cert.sh localhost

ssl-letsencrypt: ## Setup Let's Encrypt SSL certificates (requires domain and email)
	@echo "Setting up Let's Encrypt SSL..."
	@read -p "Enter your domain: " domain; \
	read -p "Enter your email: " email; \
	./scripts/setup-letsencrypt.sh $$domain $$email

# Docker Management
docker-build: ## Build Docker images
	@echo "Building Docker images..."
	@docker-compose build

docker-up: ## Start all services in detached mode
	@echo "Starting services..."
	@docker-compose up -d
	@echo "✅ Services started!"
	@echo "Access your app at: https://localhost"

docker-down: ## Stop all services
	@echo "Stopping services..."
	@docker-compose down

docker-restart: ## Restart all services
	@echo "Restarting services..."
	@docker-compose restart

docker-logs: ## View logs from all services
	@docker-compose logs -f

docker-logs-nginx: ## View nginx logs only
	@docker-compose logs -f nginx

docker-logs-nextjs: ## View Next.js logs only
	@docker-compose logs -f nextjs

docker-ps: ## Show running containers
	@docker-compose ps

docker-stats: ## Show container resource usage
	@docker stats

# Development Workflow
deploy-dev: ssl-generate docker-build docker-up ## Full development deployment
	@echo "✅ Development deployment complete!"
	@echo "Access your app at: https://localhost (accept self-signed certificate)"

deploy-prod: ssl-letsencrypt docker-build docker-up ## Full production deployment
	@echo "✅ Production deployment complete!"

# Maintenance
docker-clean: ## Stop and remove all containers, images, and volumes
	@echo "⚠️  This will remove all containers, images, and volumes!"
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker-compose down -v --rmi all; \
		echo "✅ Cleaned up!"; \
	else \
		echo "Cancelled."; \
	fi

docker-rebuild: docker-down ## Rebuild and restart with fresh build
	@echo "Rebuilding from scratch..."
	@docker-compose build --no-cache
	@docker-compose up -d
	@echo "✅ Rebuild complete!"

# Monitoring
health-check: ## Check health status of all services
	@echo "Checking nginx health..."
	@curl -f http://localhost/health || echo "❌ Nginx health check failed"
	@echo ""
	@echo "Checking Next.js health..."
	@docker-compose exec nextjs wget -O- -q http://localhost:3000 > /dev/null && echo "✅ Next.js is healthy" || echo "❌ Next.js health check failed"

backup: ## Backup SSL certificates and configs
	@mkdir -p backups/$$(date +%Y%m%d)
	@cp -r nginx/ssl backups/$$(date +%Y%m%d)/ 2>/dev/null || echo "No SSL files to backup"
	@cp -r nginx/conf.d backups/$$(date +%Y%m%d)/
	@cp .env.production backups/$$(date +%Y%m%d)/ 2>/dev/null || echo "No .env.production to backup"
	@echo "✅ Backup created in backups/$$(date +%Y%m%d)/"

