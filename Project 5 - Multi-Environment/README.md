# Multi-Environment Infrastructure with AWS ECS and Terraform

A comprehensive guide to building scalable, multi-environment infrastructure using AWS ECS, Terraform modules, and Infrastructure as Code best practices for enterprise-grade deployments.

## 🎯 What This Project Demonstrates

- **��️ Terraform Modules** - Reusable infrastructure components for AWS ECS
- **🌍 Multi-Environment Management** - Separate dev, staging, and production deployments
- **🐳 Container Orchestration** - AWS ECS with Fargate for serverless containers
- **📈 Auto-scaling** - Production-grade scaling policies and metrics
- **🔍 Observability** - CloudWatch logging and monitoring integration
- **💰 Cost Optimization** - Environment-specific resource sizing
- **🚀 CI/CD Ready** - Infrastructure designed for automated deployments

## 📋 Prerequisites

Before you begin, ensure you have:

- [Terraform](https://www.terraform.io/downloads.html) v1.0 or higher
- [AWS CLI v2](https://aws.amazon.com/cli/) installed and configured
- AWS account with appropriate permissions (ECS, IAM, CloudWatch, VPC)
- Basic Terraform knowledge
- Understanding of containers and AWS services

### AWS Permissions Required
Your AWS user/role needs these permissions:
- `AmazonECS_FullAccess`
- `IAMFullAccess`
- `CloudWatchFullAccess`
- `AmazonVPCFullAccess`

## 📁 Project Structure

```
project-5-multi-environment/
├── modules/
│   └── ecs-webapp/                # Reusable ECS infrastructure module
│       ├── main.tf               # ECS cluster, service, task definitions
│       ├── variables.tf          # Configurable parameters
│       ├── outputs.tf            # Module outputs (URLs, ARNs)
│       ├── iam.tf               # IAM roles and policies
│       ├── logs.tf              # CloudWatch log groups
│       └── autoscaling.tf       # Auto-scaling policies
├── environments/
│   ├── dev/                      # Development environment
│   │   ├── main.tf              # Dev-specific configuration
│   │   ├── variables.tf         # Dev variables
│   │   ├── terraform.tfvars     # Dev values
│   │   └── outputs.tf           # Dev outputs
│   ├── staging/                  # Staging environment (optional)
│   │   ├── main.tf              # Staging configuration
│   │   ├── variables.tf         # Staging variables
│   │   └── terraform.tfvars     # Staging values
│   └── prod/                     # Production environment
│       ├── main.tf              # Prod-specific configuration
│       ├── variables.tf         # Prod variables
│       ├── terraform.tfvars     # Prod values
│       └── outputs.tf           # Prod outputs
├── scripts/
│   ├── deploy-dev.sh            # Development deployment automation
│   ├── deploy-prod.sh           # Production deployment automation
│   ├── get-app-urls.sh          # Retrieve application URLs
│   └── cleanup-all.sh           # Clean up all environments
├── README.md                     # This file
└── .gitignore                   # Terraform and AWS-specific ignores
```

## 🚀 Quick Start Deployment

### 1. Initial Setup

```bash
# Clone and navigate to project
cd project-5-multi-environment

# Make scripts executable
chmod +x scripts/*.sh

# Verify AWS configuration
aws sts get-caller-identity
aws configure list
```

### 2. Deploy Development Environment

```bash
# Automated deployment
./scripts/deploy-dev.sh

# Or manual deployment
cd environments/dev
terraform init
terraform plan
terraform apply -auto-approve
cd ../..
```

### 3. Test Development Environment

```bash
# Get application URLs
./scripts/get-app-urls.sh

# Test the application
DEV_URL=$(cd environments/dev && terraform output -raw app_url)
curl $DEV_URL
curl $DEV_URL/health
```

### 4. Deploy Production Environment

```bash
# Automated production deployment
./scripts/deploy-prod.sh

# Or manual deployment
cd environments/prod
terraform init
terraform plan
terraform apply -auto-approve
cd ../..
```

## 🏗️ Architecture Overview

### Environment Comparison

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **CPU** | 256 (0.25 vCPU) | 512 (0.5 vCPU) | 1024 (1 vCPU) |
| **Memory** | 512 MB | 1024 MB | 2048 MB |
| **Instances** | 1 | 1-2 | 2-10 |
| **Auto-scaling** | ❌ Disabled | ✅ Basic | ✅ Advanced |
| **Log Retention** | 7 days | 14 days | 30 days |
| **Debug Mode** | ✅ Enabled | ✅ Enabled | ❌ Disabled |
| **Cost (Monthly)** | ~$15 | ~$30 | ~$100-500 |

### AWS Services Used

- **Amazon ECS** - Container orchestration with Fargate
- **Application Load Balancer** - Traffic distribution and health checks
- **CloudWatch Logs** - Centralized logging with retention policies
- **Auto Scaling** - Dynamic scaling based on CPU/memory metrics
- **IAM** - Security roles and policies for ECS tasks
- **VPC** - Network isolation and security groups

## ⚙️ Module Configuration

### ECS WebApp Module

The `modules/ecs-webapp/` creates:

#### Core Infrastructure
```hcl
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.app_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled"
  }
}

# ECS Service with Fargate
resource "aws_ecs_service" "webapp" {
  name            = "${var.environment}-${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webapp.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.webapp.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webapp.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }
}
```

#### Environment-Specific Configurations

**Development (environments/dev/terraform.tfvars)**
```hcl
app_name             = "mywebapp"
environment          = "dev"
aws_region           = "us-east-1"
container_image      = "nginx:latest"
cpu                  = "256"
memory               = "512"
desired_count        = 1
enable_autoscaling   = false
log_retention_days   = 7

environment_variables = [
  {
    name  = "DEBUG"
    value = "true"
  },
  {
    name  = "API_URL"
    value = "https://dev-api.example.com"
  }
]
```

**Production (environments/prod/terraform.tfvars)**
```hcl
app_name             = "mywebapp"
environment          = "prod"
aws_region           = "us-east-1"
container_image      = "nginx:latest"
cpu                  = "1024"
memory               = "2048"
desired_count        = 2
enable_autoscaling   = true
min_capacity         = 2
max_capacity         = 10
log_retention_days   = 30

environment_variables = [
  {
    name  = "NODE_ENV"
    value = "production"
  },
  {
    name  = "API_URL"
    value = "https://api.example.com"
  }
]
```

## 📊 Monitoring and Scaling

### CloudWatch Integration

```hcl
# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "webapp" {
  name              = "/ecs/${var.environment}-${var.app_name}"
  retention_in_days = var.log_retention_days
}

# Auto Scaling Policies
resource "aws_appautoscaling_policy" "scale_up" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.environment}-${var.app_name}-scale-up"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
```

### Monitoring Commands

```bash
# View ECS cluster status
aws ecs describe-clusters --clusters dev-mywebapp-cluster

# Check service status
aws ecs describe-services \
  --cluster dev-mywebapp-cluster \
  --services dev-mywebapp-service

# View application logs
aws logs tail /ecs/dev-mywebapp --follow

# Monitor auto-scaling
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs
```

## 🛠️ Advanced Operations

### Manual Scaling

```bash
# Scale development environment
aws ecs update-service \
  --cluster dev-mywebapp-cluster \
  --service dev-mywebapp-service \
  --desired-count 2

# Production auto-scales automatically based on CPU/memory
```

### Blue-Green Deployments

```hcl
# Enable blue-green deployments
deployment_configuration {
  maximum_percent         = 200
  minimum_healthy_percent = 50
  
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
```

### Adding New Environments

```bash
# Create staging environment
mkdir -p environments/staging
cp environments/dev/* environments/staging/

# Edit staging/terraform.tfvars
environment = "staging"
cpu         = "512"
memory      = "1024"
desired_count = 1
enable_autoscaling = true
max_capacity = 3
```

## 🔧 Troubleshooting Guide

### ❌ ECS Task Fails to Start

**Check task definition:**
```bash
aws ecs describe-task-definition \
  --task-definition dev-mywebapp:1

# Check task status
aws ecs list-tasks \
  --cluster dev-mywebapp-cluster \
  --service-name dev-mywebapp-service

# View task logs
aws logs get-log-events \
  --log-group-name /ecs/dev-mywebapp \
  --log-stream-name ecs/mywebapp/[TASK-ID]
```

### ❌ Load Balancer Health Check Fails

**Check target group health:**
```bash
aws elbv2 describe-target-health \
  --target-group-arn [TARGET-GROUP-ARN]

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids [SECURITY-GROUP-ID]
```

### ❌ Module Not Found Error

**Verify module path:**
```bash
# Ensure you're in the correct directory
pwd  # Should be in environments/dev or environments/prod

# Check module exists
ls ../../modules/ecs-webapp/main.tf
```

### ❌ AWS Permissions Issues

**Verify AWS credentials:**
```bash
aws sts get-caller-identity
aws iam get-user

# Test ECS permissions
aws ecs list-clusters
```

### ❌ Terraform State Issues

**Reset Terraform state:**
```bash
# Remove local state
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init

# Import existing resources if needed
terraform import aws_ecs_cluster.main dev-mywebapp-cluster
```

### ❌ Auto-scaling Not Working

**Check scaling policies:**
```bash
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs

# View CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=dev-mywebapp-service \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

## 🧹 Cleanup

### Destroy Specific Environment

```bash
# Destroy development
cd environments/dev
terraform destroy -auto-approve

# Destroy production
cd environments/prod
terraform destroy -auto-approve
```

### Automated Cleanup

```bash
# Clean up all environments
./scripts/cleanup-all.sh

# Verify cleanup
aws ecs list-clusters
aws logs describe-log-groups --log-group-name-prefix "/ecs/"
```

## 🎓 What You've Learned

By completing this project, you've mastered:

- ✅ **AWS ECS Fundamentals** - Container orchestration with Fargate
- ✅ **Terraform Modules** - Reusable infrastructure components
- ✅ **Multi-Environment Architecture** - Dev, staging, and production patterns
- ✅ **Auto-scaling Configuration** - Dynamic scaling based on metrics
- ✅ **Load Balancing** - Application Load Balancer integration
- ✅ **Monitoring and Logging** - CloudWatch integration
- ✅ **Security Best Practices** - IAM roles and security groups
- ✅ **Cost Optimization** - Environment-appropriate resource sizing
- ✅ **Infrastructure Operations** - Deployment, scaling, and troubleshooting

## 🔗 Next Steps

### Intermediate Enhancements
- **Database Integration**: Add RDS instances to the module
- **SSL/TLS**: Implement HTTPS with ACM certificates
- **Custom Domains**: Route 53 integration for custom domains
- **Secrets Management**: AWS Secrets Manager integration

### Advanced Features
- **Service Mesh**: Implement AWS App Mesh for microservices
- **GitOps**: Integrate with AWS CodePipeline for automated deployments
- **Multi-Region**: Deploy across multiple AWS regions
- **Disaster Recovery**: Implement backup and recovery strategies

### Production Readiness
- **Security Hardening**: Implement AWS Security Hub recommendations
- **Compliance**: SOC 2, HIPAA, or PCI DSS compliance patterns
- **Cost Management**: Implement AWS Cost Explorer and budgets
- **Performance Optimization**: Advanced ECS optimization techniques

## 📚 AWS Resources

### Essential Documentation
- [AWS ECS Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### Useful AWS CLI Commands
```bash
# ECS Operations
aws ecs list-clusters
aws ecs describe-services --cluster [CLUSTER] --services [SERVICE]
aws ecs update-service --cluster [CLUSTER] --service [SERVICE] --desired-count [N]

# CloudWatch Logs
aws logs describe-log-groups
aws logs tail [LOG-GROUP] --follow

# Load Balancer Operations
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups
aws elbv2 describe-target-health --target-group-arn [ARN]
```

## 💡 Pro Tips

### Development Workflow
1. **Always test in dev first** - Never deploy directly to production
2. **Use consistent naming** - Follow the `{environment}-{app}-{resource}` pattern
3. **Monitor costs** - Check AWS billing dashboard regularly
4. **Tag everything** - Use consistent tagging for cost allocation

### Production Best Practices
1. **Enable Container Insights** - Better monitoring and debugging
2. **Use task placement strategies** - Spread tasks across AZs
3. **Implement health checks** - Proper ALB health check configuration
4. **Plan for failure** - Design for AZ failures and auto-recovery

---

**Congratulations! 🎉** 

*You've built an enterprise-grade, multi-environment infrastructure on AWS! This pattern is used by companies worldwide to manage their container workloads at scale.*
