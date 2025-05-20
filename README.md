# Barkuni API Project

This project is a containerized API service with automated CI/CD pipeline using GitHub Actions, Docker, and Kubernetes deployment with Helm.

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # GitHub Actions workflow
├── helm/
│   └── barkuni/              # Helm chart
│       ├── Chart.yaml        # Chart metadata
│       ├── values.yaml       # Default configuration
│       └── templates/        # Kubernetes manifests
│           ├── deployment.yaml
│           ├── service.yaml
│           └── ingress.yaml  # ALB Ingress configuration
├── k8s/                      # Kubernetes manifests
├── scripts/                  # Utility scripts
│   ├── manage-certificates.sh # SSL certificate management
│   └── create_ec2.py        # EC2 instance creation script
├── terraform/               # Infrastructure as Code
├── app.py                   # Main application
├── Dockerfile              # Container definition
└── requirements.txt        # Python dependencies
```

## Prerequisites

- Docker Hub account
- AWS account with EKS cluster
- GitHub repository
- Terraform (for infrastructure deployment)
- OpenSSL (for certificate generation)
- AWS CLI configured with appropriate credentials

## Required Secrets

The following secrets need to be configured in your GitHub repository:

- `DOCKERHUB_USERNAME`: Your Docker Hub username
- `DOCKERHUB_TOKEN`: Your Docker Hub access token
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key

## SSL Certificate Management

The project includes automated SSL certificate management using AWS Certificate Manager (ACM). The process:

1. **Certificate Generation**
   - Self-signed certificates are generated using OpenSSL
   - Certificates are valid for 365 days
   - Supports wildcard domains (e.g., *.barkuni.com)

2. **Certificate Storage**
   - Certificates are stored in AWS ACM
   - Certificate ARNs are tracked locally
   - Sensitive files are automatically cleaned up

3. **Automated Management**
   - Certificates are checked and renewed automatically in CI/CD
   - Only generates new certificates when needed
   - Validates existing certificates before generation

To manage certificates manually:

```bash
# Run the certificate management script
./scripts/manage-certificates.sh
```

## AWS Load Balancer Configuration

The application is exposed via AWS Application Load Balancer (ALB) with the following features:

1. **Ingress Configuration**
   - Supports both HTTP and HTTPS
   - Automatic SSL redirect
   - Health checks configured
   - Custom domain support

2. **Domain Configuration**
   - Default domain: test.vicarius.xyz
   - Configurable in Helm values
   - SSL certificate integration

To configure the ALB:

```yaml
# In helm/barkuni/values.yaml
domainName: test.vicarius.xyz
certificateArn: "arn:aws:acm:region:account:certificate/xxx"
```

## EC2 Instance Management

The project includes a script for creating EC2 instances in AWS:

```bash
# Create an EC2 instance
python scripts/create_ec2.py \
  --subnet-id subnet-123456 \
  --ami-id ami-123456 \
  --instance-type t2.micro \
  --key-name my-key \
  --security-groups sg-123456 \
  --tags Name=test-instance Environment=dev
```

Script features:
- Support for multiple subnets
- Custom AMI selection
- Security group configuration
- Instance tagging
- Detailed instance information output

## CI/CD Pipeline

The project uses GitHub Actions for continuous integration and deployment. The pipeline consists of four main jobs:

1. **Certificate Management**
   - Checks existing certificates
   - Generates and imports new certificates if needed
   - Ensures SSL security for the application

2. **Version Bump**
   - Automatically bumps version based on commit messages
   - Uses semantic versioning (major.minor.patch)
   - Creates and pushes git tags

3. **Build and Push**
   - Builds Docker image using multi-platform support
   - Pushes to Docker Hub with version tag and latest tag
   - Supports both AMD64 and ARM64 architectures

4. **Deploy**
   - Uses Terraform for infrastructure management
   - Configures AWS EKS cluster access
   - Deploys application using Helm
   - Configures ALB and Ingress

## Accessing the Deployed Application

The application is accessible at:

- **URL:** http://test.vicarius.xyz/ (replace with your actual ALB DNS or Route53 domain if different)
- **Example API endpoint:** http://test.vicarius.xyz/health

> _Note: If the app is not yet deployed or the DNS is not public, update this section with the correct link once available._

## API Endpoints

The Flask application exposes the following endpoints:

- `GET /health` — Health check endpoint.
- `GET /pods` — _(Bonus)_ Lists all running pods in the `kube-system` namespace.  
  Example:
  ```bash
  curl http://test.vicarius.xyz/pods
  ```
  > _Requires the application to have access to the Kubernetes API and appropriate RBAC permissions._

## Development

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd barkuni-exam
   ```

2. Install dependencies:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. Run locally:
   ```bash
   python app.py
   ```

## Deployment

The application is automatically deployed when changes are pushed to the main branch. The deployment process:

1. Bumps version based on commit messages
2. Builds and pushes Docker image
3. Deploys to EKS using Helm
4. Configures ALB and Ingress
5. Sets up SSL certificates

### Manual Deployment

To deploy manually:

```bash
# Build and push Docker image
docker build -t your-username/barkuni-api:version .
docker push your-username/barkuni-api:version

# Deploy using Helm
helm upgrade --install barkuni ./helm/barkuni \
  --set image.repository=your-username/barkuni-api \
  --set image.tag=version \
  --set domainName=test.vicarius.xyz \
  --set certificateArn=arn:aws:acm:region:account:certificate/xxx
```

## Infrastructure

The infrastructure is managed using Terraform and includes:
- EKS cluster configuration
- Required AWS resources
- Network configuration
- ALB and Route53 setup

## Infrastructure Setup

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- kubectl
- helm

### AWS Load Balancer Controller Setup

1. Initialize Terraform:
```bash
cd terraform
terraform init
```

2. Apply Terraform configuration:
```bash
terraform apply
```

3. Install the AWS Load Balancer Controller:
```bash
# Add the AWS Load Balancer Controller Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f helm/aws-load-balancer-controller/values.yaml \
  --set clusterName=$(terraform output -raw cluster_name) \
  --set region=$(terraform output -raw aws_region) \
  --set vpcId=$(terraform output -raw vpc_id)
```

4. Verify the installation:
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Application Deployment

1. Update the Helm values with the certificate ARN:
```bash
# Get the certificate ARN
CERT_ARN=$(terraform output -raw certificate_arn)

# Update the values.yaml file
sed -i "s|certificateArn:.*|certificateArn: $CERT_ARN|" helm/barkuni/values.yaml
```

2. Deploy the application:
```bash
helm upgrade --install barkuni ./helm/barkuni
```

3. Verify the deployment:
```bash
kubectl get ingress
kubectl get pods
```

## Infrastructure Components

### AWS Load Balancer Controller
The AWS Load Balancer Controller manages AWS Application Load Balancers (ALB) for Kubernetes Ingress resources. It is configured with:
- IAM roles and policies for AWS resource management
- Service account for Kubernetes authentication
- Helm chart configuration for deployment
- Monitoring integration with Prometheus

### SSL Certificate Management
SSL certificates are managed through AWS Certificate Manager (ACM):
- Self-signed certificates are created for development
- Certificates are imported into ACM
- Certificate ARNs are used in Helm values for Ingress configuration

### DNS Configuration
Route53 is used for DNS management:
- Domain zone creation
- A record configuration for the ALB
- Integration with ACM certificates

### EKS Cluster
The EKS cluster is configured with:
- Managed node groups
- VPC networking
- IAM roles and policies
- OIDC provider for service account authentication

## Development

### Local Development
1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the application:
```bash
python app.py
```

### Testing
```bash
pytest
```

## CI/CD Pipeline
The project uses GitHub Actions for CI/CD:
1. Build and test the application
2. Build and push Docker images
3. Deploy to EKS using Helm
4. Configure SSL certificates
5. Update DNS records

## Monitoring and Logging
- Prometheus metrics for the AWS Load Balancer Controller
- CloudWatch logs for application and infrastructure
- ALB access logs for traffic monitoring

## Security
- IAM roles with least privilege
- SSL/TLS encryption
- Network security groups
- Pod security policies

## Contributing

1. Create a feature branch
2. Make your changes
3. Commit with conventional commit messages:
   - `feat:` for new features
   - `fix:` for bug fixes
4. Push to the branch
5. Create a Pull Request

## Running Locally with Minikube

You can run and test the Barkuni API locally using [Minikube](https://minikube.sigs.k8s.io/):

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Steps

1. Build the Docker image locally (for testing before Minikube, optional but recommended):
   ```bash
   docker build -t barkuni-api:test .
   ```

2. Make the script executable and start Minikube, then deploy the app:
   ```bash
   chmod +x scripts/start_minikube.sh
   cd scripts
   ./start_minikube.sh
   ```

3. The script will:
   - Start Minikube with Docker driver
   - Build the Docker image inside Minikube
   - Deploy the Kubernetes manifests
   - Enable the `metrics-server` addon for resource metrics

4. To access the app from your local machine:
   - Find the actual service name:
     ```bash
     kubectl get svc
     ```
   - Port-forward the service:
     ```bash
     kubectl port-forward svc/barkuni 5000:5000
     ```
   - Open [http://localhost:5000/health](http://localhost:5000/health) in your browser or use:
     ```bash
     curl http://localhost:5000/health
     ```

5. To check resource metrics (after metrics-server is ready):
   ```bash
   kubectl top pods
   ```

> _Note: For advanced monitoring, consider installing Prometheus and Grafana via Helm._

---

## Troubleshooting Tips

1. **`Error: Unable to access the Docker daemon`**
   - Ensure Docker is running.
   - If using Docker Desktop, ensure the "Expose daemon on tcp://localhost:2375 without TLS" option is enabled in Docker settings.

2. **`kubectl top pods` → `error: metrics not available yet`**
   - This usually means the metrics-server is not ready or your pods are not running yet.
   - Wait a minute and try again:
     ```bash
     kubectl get pods
     kubectl top pods
     ```
   - If it still fails, check metrics-server logs:
     ```bash
     kubectl -n kube-system logs deployment/metrics-server
     ```

3. **`curl http://localhost:5000/health` returns nothing**
   - This is expected if the port-forward is not running or the service is not found.
   - Fix the service name as above, then port-forward and try again.

4. **Update README for clarity**


## License

### MIT License