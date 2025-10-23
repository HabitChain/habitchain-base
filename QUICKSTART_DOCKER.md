# Docker Quick Start Guide

This is a quick reference for deploying HabitChain with Docker. For detailed documentation, see [DEPLOYMENT_DOCKER.md](./DEPLOYMENT_DOCKER.md).

## Prerequisites

- Docker Engine 20.10+ and Docker Compose 2.0+
- Alchemy API key and WalletConnect Project ID

## Quick Deploy (Local/Testing)

### 1. One-Command Setup

```bash
# Generate SSL cert, build, and start
make deploy-dev
```

This will:
- Generate a self-signed SSL certificate
- Build Docker images
- Start nginx and Next.js containers
- Make the app available at `https://localhost`

### 2. Manual Setup

```bash
# Generate self-signed SSL certificate
make ssl-generate

# Or manually:
./scripts/generate-ssl-cert.sh localhost

# Configure environment
cp .env.example .env.production
# Edit .env.production with your API keys

# Build and start
make docker-build
make docker-up

# View logs
make docker-logs
```

### 3. Access Application

- **HTTPS**: https://localhost (accept self-signed certificate warning)
- **HTTP**: http://localhost (redirects to HTTPS)

## Production Deployment

### 1. Setup Let's Encrypt SSL

```bash
# Interactive setup
make ssl-letsencrypt

# Or manually with your domain and email
./scripts/setup-letsencrypt.sh your-domain.com your-email@example.com
```

### 2. Update Domain Configuration

Edit `nginx/conf.d/habitchain.conf`:
```nginx
server_name your-domain.com www.your-domain.com;
```

### 3. Deploy

```bash
make deploy-prod
```

## Common Commands

```bash
# View logs
make docker-logs              # All services
make docker-logs-nginx        # Nginx only
make docker-logs-nextjs       # Next.js only

# Container management
make docker-ps                # Show running containers
make docker-stats             # Show resource usage
make docker-restart           # Restart all services
make docker-down              # Stop all services

# Maintenance
make docker-rebuild           # Rebuild with no cache
make docker-clean             # Remove everything (with confirmation)
make backup                   # Backup SSL certs and configs
make health-check             # Check service health
```

## Troubleshooting

### Services won't start

```bash
# Check logs
make docker-logs

# Verify configuration
docker-compose config

# Check if ports are in use
sudo lsof -i :80
sudo lsof -i :443
```

### Cannot access via HTTPS

```bash
# Verify SSL certificates exist
ls -la nginx/ssl/

# Check nginx config
docker-compose exec nginx nginx -t

# Restart nginx
docker-compose restart nginx
```

### Next.js build fails

```bash
# Check Next.js config includes standalone output
grep "standalone" packages/nextjs/next.config.ts

# Test build locally first
cd packages/nextjs
yarn build
```

## Environment Variables

Required in `.env.production`:
- `NEXT_PUBLIC_ALCHEMY_API_KEY` - Get from [Alchemy](https://alchemy.com)
- `NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID` - Get from [WalletConnect](https://cloud.walletconnect.com)

## Architecture

```
[Internet] → [Nginx :80/:443] → [Next.js :3000 (internal)]
```

- **Nginx**: Reverse proxy with SSL termination, security headers, rate limiting
- **Next.js**: Frontend application (production build with standalone output)
- **Docker Network**: Isolated bridge network for inter-container communication

## Security Features

- ✅ Rate limiting (10 req/s general, 20 req/s API)
- ✅ Security headers (XSS, clickjacking protection)
- ✅ Modern TLS 1.2/1.3 with strong ciphers
- ✅ Gzip compression
- ✅ Health checks
- ✅ Non-root container user

## Next Steps

After deployment:
1. Update DNS records to point to your server
2. Configure firewall (ports 80, 443)
3. Set up monitoring and alerts
4. Review security headers in `nginx/nginx.conf`
5. Enable HSTS after testing (uncomment in `nginx/conf.d/habitchain.conf`)

## Additional Resources

- **Full Documentation**: [DEPLOYMENT_DOCKER.md](./DEPLOYMENT_DOCKER.md)
- **Local Development**: [AGENTS.md](./AGENTS.md)
- **Smart Contracts**: [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Testing Guide**: [TESTING_HAPPY_PATH.md](./TESTING_HAPPY_PATH.md)

## Support

For issues:
1. Check logs: `make docker-logs`
2. Verify config: `docker-compose config`
3. Test health: `make health-check`
4. See troubleshooting in [DEPLOYMENT_DOCKER.md](./DEPLOYMENT_DOCKER.md)

