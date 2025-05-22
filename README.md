# Barkuni API Project

Simple API service with CI/CD pipeline using GitHub Actions, Docker, and EKS deployment.

## Project Structure
```
.
├── .github/workflows/
├── terraform/              
│   ├── infrastructure/
│   └── dns/          
├── scripts/               
│   └── manage-certificates.sh
│   └── start_minikube.sh
├── app.py
├── Dockerfile            
└── requirements.txt      
```

## Prerequisites
- AWS Account
- Docker Hub Account
- GitHub Account
- Configured AWS CLI

## Required GitHub Secrets
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Local Development
1. Clone and setup:
```bash
git clone <repo-url>
cd barkuni-exam
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. Run locally:
```bash
python app.py
```

## Local Kubernetes Development with Minikube

### Prerequisites
- Minikube
- kubectl
- Helm

### Setup Local Environment
1. Start Minikube:
```bash
chmod +x scripts/start_minikube.sh &&
./scripts/start_minikube.sh
```

2. Verify Installation:
```bash
minikube status
kubectl get nodes
```

3. Install NGINX Ingress:
```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

4. Deploy Application:
```bash
# Build local image
docker build -t local/barkuni-api:dev .

# Load image into Minikube
minikube image load local/barkuni-api:dev

# Deploy using kubectl
kubectl create namespace dev
kubectl apply -f kubernetes/dev/
```

5. Access Application:
```bash
# Get Minikube IP
minikube ip

# Add to /etc/hosts
echo "$(minikube ip) test.vicarius.local" | sudo tee -a /etc/hosts

# Access endpoints
curl http://test.vicarius.local/health
curl http://test.vicarius.local/pods
```

### Debugging Tips
- View logs: `kubectl logs -n dev deployment/barkuni-api`
- Shell access: `kubectl exec -it -n dev deployment/barkuni-api -- /bin/sh`
- Restart deployment: `kubectl rollout restart -n dev deployment/barkuni-api`
- Clean up: `minikube delete`

## AWS Deployment
The project is automatically deployed via GitHub Actions pipeline:

1. Infrastructure (EKS):
```bash
cd terraform/infrastructure
terraform init
terraform apply
```

2. Check deployment:
```bash
# Configure kubectl
aws eks update-kubeconfig --name barkuni-exam-cluster --region us-east-1

# Verify resources
kubectl get nodes
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

3. Access the application:
- Health check: https://test.vicarius.xyz/health
- Pods info: https://test.vicarius.xyz/pods

## CI/CD Pipeline
Push to main branch triggers:
1. SSL Certificate management
2. Version bumping
3. Docker image build/push
4. EKS deployment with:
   - AWS Load Balancer Controller
   - NGINX Ingress
   - Route53 DNS configuration

## Infrastructure Components
- EKS Cluster
- AWS Load Balancer (NLB)
- NGINX Ingress Controller
- Route53 DNS
- ACM Certificates

## Commit Convention
- `feat:` - New features
- `fix:` - Bug fixes

## Monitoring
- Check AWS Console:
  - EKS Cluster status
  - Load Balancer health
  - Route53 records
- Kubernetes:
  ```bash
  kubectl get pods -A
  kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
  ```

## Troubleshooting

### Manual Verification Steps
1. Check AWS Load Balancer Controller:
```bash
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl -n kube-system describe deployment aws-load-balancer-controller
```

2. Verify EKS Configuration:
```bash
# Check OIDC provider
aws eks describe-cluster --name barkuni-exam-cluster --query "cluster.identity.oidc"

# Check node IAM role permissions
aws iam list-attached-role-policies --role-name $(aws eks describe-nodegroup --cluster-name barkuni-exam-cluster --nodegroup-name general --query 'nodegroup.nodeRole' --output text)
```

3. Verify Network Configuration:
```bash
# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name barkuni-exam-cluster --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Check subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,MapPublicIpOnLaunch]'

# Check security groups
aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID
```

### Common Issues
1. Load Balancer not creating:
   - Check AWS Load Balancer Controller logs
   - Verify IAM roles and policies
   - Ensure subnets are tagged properly
   - Check security group permissions