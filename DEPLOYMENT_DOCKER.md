# Docker Deployment Guide

This guide covers deploying HabitChain using Docker Compose with Nginx as a reverse proxy.

## Architecture

The deployment consists of:
- **Next.js container**: Runs the frontend application on port 3000 (internal)
- **Nginx container**: Reverse proxy handling HTTP (80) and HTTPS (443) traffic
- **Docker network**: Isolated bridge network for inter-container communication

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- A domain name (for production with Let's Encrypt)
- Alchemy API key
- WalletConnect Project ID

## Quick Start (Development/Testing)

### 1. Generate Self-Signed SSL Certificate

For local testing or development:

```bash
chmod +x scripts/generate-ssl-cert.sh
./scripts/generate-ssl-cert.sh localhost
```

This creates:
- `nginx/ssl/cert.pem` - SSL certificate
- `nginx/ssl/key.pem` - Private key

### 2. Configure Environment Variables

```bash
cp .env.production.example .env.production
```

Edit `.env.production` and set:
```env
NEXT_PUBLIC_ALCHEMY_API_KEY=your_actual_key
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_actual_project_id
```

### 3. Update Next.js Config for Standalone Build

Edit `packages/nextjs/next.config.ts` and add:

```typescript
const nextConfig: NextConfig = {
  // ... existing config
  output: 'standalone',
  // ... rest of config
};
```

### 4. Build and Start

```bash
# Build the Docker images
docker-compose build

# Start the services
docker-compose up -d

# View logs
docker-compose logs -f
```

### 5. Access the Application

- **HTTPS**: https://localhost (you'll need to accept the self-signed certificate warning)
- **HTTP**: http://localhost (will redirect to HTTPS)

## Production Deployment

### 1. Set Up Let's Encrypt SSL

For production with a real domain:

```bash
chmod +x scripts/setup-letsencrypt.sh
./scripts/setup-letsencrypt.sh your-domain.com your-email@example.com
```

This script will:
1. Install certbot if needed
2. Configure nginx for Let's Encrypt validation
3. Request SSL certificates
4. Update nginx configuration
5. Set up automatic certificate renewal

### 2. Update Nginx Configuration for Your Domain

Edit `nginx/conf.d/habitchain.conf` and replace `server_name _;` with:

```nginx
server_name your-domain.com www.your-domain.com;
```

### 3. Configure Firewall

Ensure ports 80 and 443 are open:

```bash
# Ubuntu/Debian with ufw
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# RHEL/CentOS with firewalld
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 4. Deploy

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f nginx
docker-compose logs -f nextjs
```

## Nginx Configuration Details

### Security Features

The nginx configuration includes:
- **Rate limiting**: 10 req/s for general traffic, 20 req/s for API routes
- **Security headers**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- **Modern SSL/TLS**: TLS 1.2 and 1.3 with strong cipher suites
- **Gzip compression**: For text/js/css/json files
- **HSTS**: Strict-Transport-Security (uncomment after testing)

### Custom Configuration

To customize nginx:

1. Edit `nginx/nginx.conf` for global settings
2. Edit `nginx/conf.d/habitchain.conf` for application-specific settings
3. Restart nginx: `docker-compose restart nginx`

## Monitoring and Logs

### View Logs

```bash
# All services
docker-compose logs -f

# Nginx only
docker-compose logs -f nginx

# Next.js only
docker-compose logs -f nextjs

# Last 100 lines
docker-compose logs --tail=100
```

### Check Container Status

```bash
# List running containers
docker-compose ps

# Check resource usage
docker stats

# Inspect container health
docker inspect habitchain-nginx --format='{{json .State.Health}}'
docker inspect habitchain-nextjs --format='{{json .State.Health}}'
```

### Nginx Logs

Nginx logs are stored in `nginx/logs/`:
- `nginx/logs/access.log` - All HTTP requests
- `nginx/logs/error.log` - Nginx errors

## Maintenance

### Update Application

```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build --no-cache nextjs
docker-compose up -d
```

### Update Nginx Only

```bash
# After changing nginx configs
docker-compose restart nginx
```

### Renew SSL Certificates (Manual)

If using Let's Encrypt, certificates auto-renew. To force renewal:

```bash
docker-compose run --rm certbot renew
docker-compose restart nginx
```

### Clean Up

```bash
# Stop and remove containers
docker-compose down

# Remove all images and volumes
docker-compose down -v --rmi all

# Clean Docker system
docker system prune -a
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker-compose logs nextjs
docker-compose logs nginx

# Verify configuration
docker-compose config

# Check if ports are already in use
sudo lsof -i :80
sudo lsof -i :443
```

### SSL Certificate Issues

```bash
# Verify certificate files exist
ls -la nginx/ssl/

# Test SSL configuration
docker-compose exec nginx nginx -t

# Check certificate expiry
openssl x509 -in nginx/ssl/cert.pem -noout -enddate
```

### Next.js Build Fails

```bash
# Check if standalone output is configured
grep "output:" packages/nextjs/next.config.ts

# Build locally first to test
cd packages/nextjs
yarn build

# Check for TypeScript errors
yarn next:check-types
```

### Cannot Access Application

```bash
# Verify nginx is proxying correctly
docker-compose exec nginx curl -I http://nextjs:3000

# Check if Next.js is responding
docker-compose exec nextjs wget -O- http://localhost:3000

# Verify DNS (production)
nslookup your-domain.com

# Check firewall
sudo ufw status
```

### High Memory Usage

```bash
# Check container stats
docker stats

# Restart with memory limits
docker-compose down
docker-compose up -d --force-recreate --memory="512m"
```

## Performance Optimization

### Enable HTTP/2 Server Push

Edit `nginx/conf.d/habitchain.conf`:

```nginx
location / {
    # ... existing config
    http2_push_preload on;
}
```

### Increase Worker Connections

Edit `nginx/nginx.conf`:

```nginx
events {
    worker_connections 2048;  # Increase from 1024
    use epoll;
}
```

### Add Redis Caching (Optional)

Add to `docker-compose.yml`:

```yaml
services:
  redis:
    image: redis:alpine
    container_name: habitchain-redis
    restart: unless-stopped
    networks:
      - habitchain-network
```

## Security Best Practices

1. **Keep Docker Updated**: Regularly update Docker and images
2. **Scan for Vulnerabilities**: Use `docker scan habitchain-nextjs`
3. **Use Secrets**: Never commit `.env.production` to version control
4. **Enable HSTS**: Uncomment HSTS header in nginx config after testing
5. **Monitor Logs**: Regularly check for suspicious activity
6. **Backup**: Backup SSL certificates and environment files
7. **Limit Access**: Use firewall rules to restrict access to necessary ports only

## Backup and Restore

### Backup

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup SSL certificates
cp -r nginx/ssl backups/$(date +%Y%m%d)/

# Backup environment
cp .env.production backups/$(date +%Y%m%d)/

# Backup nginx configs
cp -r nginx/conf.d backups/$(date +%Y%m%d)/
```

### Restore

```bash
# Restore from backup
BACKUP_DATE=20240101  # Replace with your backup date
cp -r backups/$BACKUP_DATE/ssl nginx/
cp backups/$BACKUP_DATE/.env.production .
cp -r backups/$BACKUP_DATE/conf.d nginx/

# Restart services
docker-compose restart
```

## Support

For issues specific to:
- **Smart Contracts**: See `DEPLOYMENT.md`
- **Local Development**: See `AGENTS.md`
- **Testing**: See `TESTING_HAPPY_PATH.md`

