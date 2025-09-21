# Development environment variables
# This file contains development-specific configuration for the ECS webapp

# Required configuration
app_name        = "myapp-dev"  # Unique name for development environment
aws_region      = "us-east-1"  # Development region
container_image = "nginx:latest"  # Base image for development
container_port  = 80  # Application port

# Development-specific resource allocation
cpu                = "256"      # Reduced CPU for cost savings in dev
memory             = "512"      # Minimal memory for development
desired_count      = 1          # Single instance for development
log_retention_days = 7          # Short log retention for dev

# Networking configuration for development
vpc_id           = "vpc-1234567890abcdef0"  # Development VPC
public_subnet_ids = ["subnet-abc123", "subnet-def456"]  # Public subnets for easy access
assign_public_ip = true  # Public IP for development access

# Development environment variables
extra_environment_variables = [
  {
    name  = "ENVIRONMENT"
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
    name  = "API_URL"
    value = "https://dev-api.example.com"
  },
  {
    name  = "FEATURE_FLAGS"
    value = "experimental-feature,debug-mode"
  }
]

# Development tags for cost tracking and management
tags = {
  Environment   = "dev"
  CostCenter    = "engineering-dev"
  Project       = "myapp"
  ManagedBy     = "terraform"
  AutoShutdown  = "true"  # Enable auto-shutdown during non-working hours
  Owner         = "development-team@company.com"
}

# Optional: IAM role overrides (if using custom roles)
# task_role_arn      = "arn:aws:iam::123456789012:role/dev-ecs-task-role"
# execution_role_arn = "arn:aws:iam::123456789012:role/dev-ecs-execution-role"

# Development-specific deployment settings
deployment_max_percent = 200  # Allow full deployment flexibility
deployment_min_percent = 0    # Allow zero tasks during deployment in dev

# Health check settings for development
health_check_grace_period_seconds = 120  # Longer grace period for dev

# Development auto-scaling (typically disabled or minimal)
enable_autoscaling = false
autoscaling_min_capacity = 1
autoscaling_max_capacity = 2  # Small buffer if needed

# Development security settings
enable_ssh_access = true  # Enable SSH for debugging (if supported by module)