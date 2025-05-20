#!/bin/bash
set -e

# Ensure docker is running
if ! docker info >/dev/null 2>&1; then
  echo "Docker must be running to use the docker driver."
  exit 1
fi

# Build Docker image locally before starting Minikube (for local test/validation)
echo "Building Docker image locally for validation..."
docker build -t barkuni-api:test ..

# Start Minikube using Docker driver
minikube start --driver=docker --nodes=1 --cpus=2 --memory=2g

# Build and load the image into Minikube
eval $(minikube docker-env)

echo "Building Docker image inside Minikube..."
docker build -t barkuni-api:test ..

# Deploy using Helm instead of raw manifests
echo "Deploying Barkuni API with Helm..."
helm upgrade --install barkuni ../helm/barkuni \
  --set image.repository=barkuni-api \
  --set image.tag=test

# Enable metrics-server addon in Minikube (install specific version if needed)
echo "Enabling metrics-server addon in Minikube..."
minikube addons enable metrics-server

# Wait for metrics-server to be ready
echo "Waiting for metrics-server to be ready..."
kubectl rollout status deployment/metrics-server -n kube-system --timeout=120s

echo "Barkuni API deployed to Minikube."

echo ""
echo "To test the app in Minikube:"
echo "First, check the service name:"
echo "  kubectl get svc"
echo "Port-forward the service to localhost (replace <actual-service-name> as needed):"
echo "  kubectl port-forward svc/<actual-service-name> 5000:5000"
echo "Then open http://localhost:5000/health in your browser or run:"
echo "  curl http://localhost:5000/health"
echo ""
echo "To check metrics (after metrics-server is ready):"
echo "  kubectl top pods"
echo ""
echo "For EKS, expose your service via LoadBalancer or Ingress and use the external URL."