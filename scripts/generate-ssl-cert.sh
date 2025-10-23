#!/bin/bash

# Script to generate self-signed SSL certificates for local/testing deployment
# For production, use Let's Encrypt instead (see setup-letsencrypt.sh)

set -e

SSL_DIR="./nginx/ssl"
DOMAIN="${1:-base.habitchain.xyz}"

echo "Generating self-signed SSL certificate for domain: $DOMAIN"

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$SSL_DIR/key.pem" \
  -out "$SSL_DIR/cert.pem" \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:www.$DOMAIN,DNS:localhost"

echo "✅ Self-signed certificate generated:"
echo "   Certificate: $SSL_DIR/cert.pem"
echo "   Private Key: $SSL_DIR/key.pem"
echo ""
echo "⚠️  WARNING: This is a self-signed certificate for testing only!"
echo "   For production, use Let's Encrypt (see setup-letsencrypt.sh)"

