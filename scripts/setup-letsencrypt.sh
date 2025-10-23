#!/bin/bash

# Script to set up Let's Encrypt SSL certificates for production deployment
# Usage: ./scripts/setup-letsencrypt.sh your-domain.com your-email@example.com

set -e

DOMAIN="$1"
EMAIL="$2"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Usage: $0 <domain> <email>"
    echo "Example: $0 base.habitchain.xyz admin@example.com"
    exit 1
fi

echo "Setting up Let's Encrypt SSL for domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

SSL_DIR="./nginx/ssl"
mkdir -p "$SSL_DIR"

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "❌ Certbot is not installed. Installing..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install certbot
    else
        echo "❌ Unsupported OS. Please install certbot manually."
        exit 1
    fi
fi

echo "✅ Certbot is installed"
echo ""

# Create temporary nginx config for certbot validation
cat > ./nginx/conf.d/letsencrypt.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 "Let's Encrypt validation server\n";
        add_header Content-Type text/plain;
    }
}
EOF

sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" ./nginx/conf.d/letsencrypt.conf

echo "📝 Created Let's Encrypt validation config"
echo ""

# Update docker-compose to include certbot
cat > docker-compose.letsencrypt.yml << 'EOF'
version: '3.8'

services:
  certbot:
    image: certbot/certbot
    container_name: habitchain-certbot
    volumes:
      - ./nginx/ssl/letsencrypt:/etc/letsencrypt
      - ./nginx/ssl/certbot:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

volumes:
  certbot-data:
EOF

echo "🚀 Starting nginx for Let's Encrypt validation..."
docker-compose up -d nginx

echo "⏳ Waiting for nginx to be ready..."
sleep 5

echo "🔐 Requesting SSL certificate from Let's Encrypt..."
docker run --rm \
    -v "$(pwd)/nginx/ssl/letsencrypt:/etc/letsencrypt" \
    -v "$(pwd)/nginx/ssl/certbot:/var/www/certbot" \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN"

# Update nginx config to use Let's Encrypt certificates
sed -i.bak \
    -e "s|ssl_certificate /etc/nginx/ssl/cert.pem;|ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;|g" \
    -e "s|ssl_certificate_key /etc/nginx/ssl/key.pem;|ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;|g" \
    ./nginx/conf.d/habitchain.conf

# Update docker-compose to mount Let's Encrypt certs
cat >> docker-compose.yml << 'EOF'

  # Let's Encrypt certificate auto-renewal
  certbot:
    image: certbot/certbot
    container_name: habitchain-certbot
    restart: unless-stopped
    volumes:
      - ./nginx/ssl/letsencrypt:/etc/letsencrypt
      - ./nginx/ssl/certbot:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
EOF

echo ""
echo "✅ Let's Encrypt SSL certificate obtained successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Update nginx volume mounts in docker-compose.yml:"
echo "      - ./nginx/ssl/letsencrypt:/etc/letsencrypt:ro"
echo "      - ./nginx/ssl/certbot:/var/www/certbot:ro"
echo ""
echo "   2. Restart nginx: docker-compose restart nginx"
echo ""
echo "   3. Verify HTTPS is working: https://$DOMAIN"
echo ""
echo "🔄 Certificate auto-renewal is configured via certbot container"

