#!/bin/bash
set -e

# Configuration
DOMAIN_NAME="*.barkuni.com"  # Replace with your domain
CERT_DIR="./certs"
CERT_FILE="$CERT_DIR/tls.crt"
KEY_FILE="$CERT_DIR/tls.key"

# Create certs directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Main execution
echo "Checking certificate status..."

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
  echo "Certificate already exists, skipping generation."
else
  echo "Generating new self-signed certificate..."
  openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=${DOMAIN_NAME:-localhost}/O=Barkuni"
fi

echo "Self-signed certificate is ready at $CERT_FILE and $KEY_FILE."