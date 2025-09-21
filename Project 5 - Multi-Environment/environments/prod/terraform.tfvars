# Production environment variables

# Application Configuration
app_name        = "myapp-prod"
environment     = "production"
aws_region      = "us-east-1"
aws_account_id  = "123456789012"  # Replace with your AWS account ID

# Container Configuration
container_image = "nginx:stable"
container_port  = 80
host_port       = 80
protocol        = "HTTP"

# Resource Sizing
cpu_units       = 1024
memory_mb       = 2048
desired_count   = 2
min_capacity    = 2
max_capacity    = 10

# Networking
vpc_id          = "vpc-12345678"  # Replace with your VPC ID
subnets         = ["subnet-abc123", "subnet-def456", "subnet-ghi789"]  # Replace with your subnet IDs

# Auto Scaling Configuration
scaling_policy = {
  target_cpu_utilization    = 75
  target_memory_utilization = 80
  scale_out_cooldown        = 60
  scale_in_cooldown         = 300
}

# Logging & Monitoring
log_retention_days = 30
cloudwatch_namespace = "MyApp/Production"

# Security
task_execution_role = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
task_role          = "arn:aws:iam::123456789012:role/ecsTaskRole"

# Health Check
health_check_path = "/health"
health_check_interval = 30
health_check_timeout  = 5
health_check_healthy_threshold = 2
health_check_unhealthy_threshold = 3

# Tags
tags = {
  Environment = "production"
  Application = "myapp"
  Owner       = "devops-team"
  CostCenter  = "prod-123"
  ManagedBy   = "terraform"
}