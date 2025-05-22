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

## EC2 Instance Management

### Prerequisites
- Python 3.x
- boto3 (`pip install boto3`)
- AWS credentials configured in `~/.aws/credentials` or environment variables

### EC2 Creation Script Features
- Create instances in specific subnets
- Support multiple OS types via AMI IDs
- Custom instance types
- SSH key pair assignment
- Security group configuration
- Custom tagging support

### Common AMI IDs by Region (us-east-1)
- Amazon Linux 2023: ami-0230bd60aa48260c6
- Ubuntu 22.04: ami-0261755bbcb8c4a84
- Windows Server 2022: ami-0d86c69530d0a048e

### Usage Examples

1. Basic instance creation:
```bash
python scripts/create_ec2.py \
  --subnet-id subnet-xxx \
  --ami-id ami-0230bd60aa48260c6
```

2. Advanced configuration:
```bash
python scripts/create_ec2.py \
  --subnet-id subnet-xxx \
  --ami-id ami-0230bd60aa48260c6 \
  --instance-type t2.small \
  --key-name my-ssh-key \
  --security-groups sg-xxx sg-yyy \
  --tags Name=webserver Environment=dev Project=barkuni
```

### Available Options
- `--subnet-id`: (Required) Subnet ID where to launch instance
- `--ami-id`: (Required) AMI ID to use
- `--instance-type`: Instance type (default: t2.micro)
- `--key-name`: SSH key pair name
- `--security-groups`: List of security group IDs
- `--tags`: List of tags in key=value format

### Output Information
- Instance ID
- Instance State
- Public IP (if available)
- Private IP

## License

MIT License

Copyright (c) 2025 Barkuni

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.