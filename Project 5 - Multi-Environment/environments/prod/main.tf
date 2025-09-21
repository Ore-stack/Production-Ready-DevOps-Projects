# Production environment configuration
# This configuration sets up an ECS webapp with production-grade settings

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for production state file
  backend "s3" {
    bucket         = "terraform-state-prod-${var.aws_account_id}"
    key            = "environments/prod/terraform.tfstate"
    region         = var.aws_region
    encrypt        = true
    dynamodb_table = "terraform-state-lock-prod"
    acl            = "bucket-owner-full-control"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment    = "prod"
      Project        = "multi-env-webapp"
      ManagedBy      = "terraform"
      Owner          = "production-team"
      CostCenter     = "production"
      DataClassification = "confidential"
      Compliance     = "hipaa,pci"
    }
  }

  # Assume production IAM role for enhanced security
  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/terraform-prod-role"
  }
}

# Local values for production-specific configuration
locals {
  prod_settings = {
    cpu                = "1024"      # Adequate resources for production load
    memory             = "2048"      # Sufficient memory for production
    desired_count      = 3           # Multiple instances across AZs for HA
    log_retention_days = 90          # Extended retention for compliance
    enable_autoscaling = true        # Auto scaling for production variability
  }

  # Production-specific environment variables
  prod_environment_variables = concat([
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "LOG_LEVEL"
      value = "warn"
    },
    {
      name  = "API_BASE_URL"
      value = "https://api.example.com"
    },
    {
      name  = "ENABLE_METRICS"
      value = "true"
    },
    {
      name  = "REQUEST_TIMEOUT"
      value = "30000"
    }
  ], var.extra_environment_variables)

  # Production secrets (reference to AWS Secrets Manager)
  prod_secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:prod/${var.app_name}/database-url"
    },
    {
      name      = "API_KEYS"
      valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:prod/${var.app_name}/api-keys"
    },
    {
      name      = "ENCRYPTION_KEY"
      valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:prod/${var.app_name}/encryption-key"
    }
  ]
}

module "webapp" {
  source = "../../modules/ecs-webapp"

  # Basic configuration
  environment     = "prod"
  app_name        = var.app_name
  aws_region      = var.aws_region
  container_image = var.container_image
  container_port  = var.container_port
  host_port       = 0  # Use dynamic port mapping with load balancer

  # Production resource allocation
  cpu                = local.prod_settings.cpu
  memory             = local.prod_settings.memory
  desired_count      = local.prod_settings.desired_count
  log_retention_days = local.prod_settings.log_retention_days

  # Networking - private subnets for security
  vpc_id           = var.vpc_id
  subnet_ids       = var.private_subnet_ids  # Use private subnets for production
  assign_public_ip = false  # No public IP for production tasks

  # Environment configuration
  environment_variables = local.prod_environment_variables
  secrets              = local.prod_secrets

  # Deployment configuration - conservative rollout
  deployment_max_percent = 150  # Only 50% extra capacity during deployment
  deployment_min_percent = 75   # Maintain 75% healthy capacity during deployment

  # Auto scaling for production load
  enable_autoscaling       = local.prod_settings.enable_autoscaling
  autoscaling_min_capacity = 3    # Minimum for high availability
  autoscaling_max_capacity = 20   # Scale for peak traffic
  autoscaling_cpu_target   = 65   # Conservative CPU target
  autoscaling_memory_target = 70  # Conservative memory target

  # Health check - shorter grace period for production
  health_check_grace_period_seconds = 30

  # Production IAM roles (should be pre-created with least privilege)
  task_role_arn       = var.task_role_arn
  execution_role_arn  = var.execution_role_arn

  # Additional production tags
  tags = merge(var.tags, {
    Environment        = "prod"
    CostCenter         = "production"
    SLA               = "99.9"
    Backup            = "true"
    DisasterRecovery  = "multi-az"
  })
}

# Production monitoring and alerting
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "prod-${var.app_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "High CPU utilization in production ECS service"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ClusterName = module.webapp.cluster_name
    ServiceName = module.webapp.service_name
  }
}

# Production outputs
output "production_endpoint" {
  description = "Production load balancer endpoint"
  value       = module.webapp.load_balancer_dns
}

output "production_arns" {
  description = "Production resource ARNs"
  value = {
    cluster_arn = module.webapp.cluster_arn
    service_arn = module.webapp.service_arn
    task_definition_arn = module.webapp.task_definition_arn
  }
}