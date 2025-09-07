# ==============================================================================
# Terraform Variables Configuration
# ==============================================================================
# This file contains environment-specific variables for your Terraform deployment
# Update these values according to your specific environment needs

# Cluster Configuration
cluster_name     = "my-devops-cluster"  # Unique name for your ECS/EKS cluster
region       = "us-east-1"          # AWS region for deployment (us-east-1, us-west-2, eu-west-1, etc.)
environment      = "dev"                # Environment tag (dev, staging, prod)

# Container Configuration
container_image  = "nginx:latest"       # Docker image with tag for deployment