# Development environment configuration
# This configuration sets up an ECS webapp with development-specific settings

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for state file (uncomment and configure for team use)
  # backend "s3" {
  #   bucket         = "terraform-state-dev-${var.aws_account_id}"
  #   key            = "environments/dev/terraform.tfstate"
  #   region         = var.aws_region
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock-dev"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "multi-env-webapp"
      ManagedBy   = "terraform"
      Owner       = "development-team"
      CostCenter  = "dev-engineering"
    }
  }

  # Assume development IAM role (uncomment if using cross-account access)
  # assume_role {
  #   role_arn = "arn:aws:iam::${var.dev_account_id}:role/terraform-dev-role"
  # }
}

# Local values for development-specific configuration
locals {
  dev_settings = {
    cpu                = "256"      # Small resources for development
    memory             = "512"      # Minimal memory allocation
    desired_count      = 1          # Single instance for cost efficiency
    log_retention_days = 7          # Short retention for development logs
    enable_autoscaling = false      # No autoscaling in development
    assign_public_ip   = true       # Public IP for easier development access
  }

  # Development-specific environment variables
  dev_environment_variables = concat([
    {
      name  = "NODE_ENV"
      value = "development"
    },
    {
      name  = "DEBUG"
      value = "true"
    },
    {
      name  = "LOG_LEVEL"
      value = "debug"
    },
    {
      name  = "API_BASE_URL"
      value = "https://dev-api.example.com"
    }
  ], var.extra_environment_variables)

  # Development-specific secrets (reference to Parameter Store)
  dev_secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = "/dev/${var.app_name}/database-url"
    },
    {
      name      = "API_KEY"
      valueFrom = "/dev/${var.app_name}/api-key"
    }
  ]
}

module "webapp" {
  source = "../../modules/ecs-webapp"

  # Basic configuration
  environment     = "dev"
  app_name        = var.app_name
  aws_region      = var.aws_region
  container_image = var.container_image
  container_port  = var.container_port
  host_port       = 0  # Dynamic port mapping for development

  # Development-specific resource allocation
  cpu                = local.dev_settings.cpu
  memory             = local.dev_settings.memory
  desired_count      = local.dev_settings.desired_count
  log_retention_days = local.dev_settings.log_retention_days

  # Networking (ensure these are provided or have defaults in module)
  vpc_id           = var.vpc_id
  subnet_ids       = var.public_subnet_ids  # Use public subnets for dev access
  assign_public_ip = local.dev_settings.assign_public_ip

  # Environment configuration
  environment_variables = local.dev_environment_variables
  secrets              = local.dev_secrets

  # Deployment configuration
  deployment_max_percent = 200  # Allow full deployment flexibility
  deployment_min_percent = 0    # Allow zero tasks during deployment

  # Auto scaling (disabled for development)
  enable_autoscaling       = local.dev_settings.enable_autoscaling
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 2  # Small buffer if needed

  # Health check (longer grace period for development)
  health_check_grace_period_seconds = 120

  # Optional role overrides (if using custom roles)
  task_role_arn       = var.task_role_arn
  execution_role_arn  = var.execution_role_arn

  # Additional tags for cost tracking and management
  tags = merge(var.tags, {
    Environment = "dev"
    CostCenter  = "development"
    AutoShutdown = "true"  # Flag for potential auto-shutdown during off-hours
  })
}

# Development-specific additional resources
resource "aws_cloudwatch_dashboard" "dev_dashboard" {
  dashboard_name = "dev-${var.app_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", module.webapp.service_name, "ClusterName", module.webapp.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service Metrics (Dev)"
        }
      }
    ]
  })
}

# Outputs specific to development environment
output "dev_service_url" {
  description = "URL to access the development service"
  value       = "http://${module.webapp.service_name}.dev.internal:${var.container_port}"
}

output "dev_log_group" {
  description = "CloudWatch log group for development logs"
  value       = module.webapp.log_group_name
}

output "dev_task_definition" {
  description = "Development task definition ARN"
  value       = module.webapp.task_definition_arn
}