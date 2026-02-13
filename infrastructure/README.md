# Industry Night Infrastructure

AWS and Kubernetes configuration for deploying Industry Night.

## Structure

```
infrastructure/
├── eks/              # EKS cluster configuration
├── k8s/              # Kubernetes manifests
└── terraform/        # (Optional) Terraform IaC
```

## EKS Cluster

### Prerequisites

- AWS CLI configured with appropriate credentials
- eksctl installed
- kubectl installed

### Creating the Cluster

```bash
eksctl create cluster -f eks/cluster.yaml
```

### Updating kubeconfig

```bash
aws eks update-kubeconfig --name industrynight-prod --region us-east-1
```

## Kubernetes Deployment

### Prerequisites

1. EKS cluster running
2. AWS Load Balancer Controller installed
3. External Secrets Operator installed (optional)

### Deploying

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secrets (update values first!)
kubectl apply -f k8s/secrets.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

## Architecture

See `docs/aws_architecture.md` for the full architecture diagram.

### Key Components

- **EKS Cluster:** Managed Kubernetes
- **RDS PostgreSQL:** Database
- **S3:** Asset storage
- **ALB:** Load balancer via AWS Load Balancer Controller
- **Secrets Manager:** Credentials storage
- **ECR:** Container registry
