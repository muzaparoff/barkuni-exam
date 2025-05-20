#!/bin/bash

# Configuration
DOMAIN_NAME="*.barkuni.com"  # Replace with your domain
CERT_DIR="./certs"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"
CERT_ARN_FILE="$CERT_DIR/cert_arn.txt"
REGION="us-east-1"

# Create certs directory if it doesn't exist
mkdir -p $CERT_DIR

# Function to check if certificate exists in ACM
check_certificate_exists() {
    if [ -f "$CERT_ARN_FILE" ]; then
        CERT_ARN=$(cat $CERT_ARN_FILE)
        aws acm describe-certificate --certificate-arn $CERT_ARN --region $REGION > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Certificate exists in ACM with ARN: $CERT_ARN"
            return 0
        else
            echo "Certificate ARN exists but certificate not found in ACM"
            return 1
        fi
    fi
    return 1
}

# Function to generate self-signed certificate
generate_certificate() {
    echo "Generating new self-signed certificate..."
    openssl req -x509 -newkey rsa:2048 -keyout $KEY_FILE -out $CERT_FILE -days 365 -nodes \
        -subj "/CN=$DOMAIN_NAME" \
        -addext "subjectAltName = DNS:$DOMAIN_NAME"
    
    if [ $? -ne 0 ]; then
        echo "Failed to generate certificate"
        exit 1
    fi
}

# Function to import certificate to ACM
import_certificate() {
    echo "Importing certificate to ACM..."
    CERT_ARN=$(aws acm import-certificate \
        --certificate fileb://$CERT_FILE \
        --private-key fileb://$KEY_FILE \
        --region $REGION \
        --query 'CertificateArn' \
        --output text)
    
    if [ $? -eq 0 ]; then
        echo "Certificate imported successfully"
        echo $CERT_ARN > $CERT_ARN_FILE
    else
        echo "Failed to import certificate"
        exit 1
    fi
}

# Main execution
echo "Checking certificate status..."

if check_certificate_exists; then
    echo "Using existing certificate"
else
    echo "Certificate not found, generating new one..."
    generate_certificate
    import_certificate
fi

# Clean up sensitive files
if [ -f "$KEY_FILE" ]; then
    rm $KEY_FILE
fi
if [ -f "$CERT_FILE" ]; then
    rm $CERT_FILE
fi

echo "Certificate management completed successfully" 