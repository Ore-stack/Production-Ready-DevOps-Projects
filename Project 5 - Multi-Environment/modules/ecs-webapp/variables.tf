# Module variables for ECS service configuration
# These variables allow customization of the ECS cluster, service, and task definition

# Required variables - must be provided by the module user
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod). Used for resource naming and tagging."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod", "development", "production", "test"], lower(var.environment))
    error_message = "Environment must be one of: dev, development, staging, test, prod, production."
  }
}

variable "app_name" {
  description = "Application name. Used for resource naming and tagging."
  type        = string
  validation {
    condition     = length(var.app_name) >= 2 && length(var.app_name) <= 32
    error_message = "App name must be between 2 and 32 characters."
  }
}

variable "container_image" {
  description = "Docker image URI to run (e.g., account-id.dkr.ecr.region.amazonaws.com/repo:tag)"
  type        = string
  validation {
    condition     = can(regex("^[^:]+:[^:]+$", var.container_image)) || can(regex("^\\d+\\.dkr\\.ecr\\.\\w+-\\w+-\\d+\\.amazonaws\\.com/", var.container_image))
    error_message = "Container image must be in format 'repository:tag' or ECR URI format."
  }
}

# Optional variables with defaults
variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1, eu-west-1)."
  }
}

variable "container_port" {
  description = "Port the container listens on. This should match the port your application listens on."
  type        = number
  default     = 3000
  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "host_port" {
  description = "Port on the host to bind to the container port. Set to 0 for dynamic port mapping."
  type        = number
  default     = 0
  validation {
    condition     = var.host_port >= 0 && var.host_port <= 65535
    error_message = "Host port must be between 0 and 65535."
  }
}

variable "cpu" {
  description = "CPU units for the task (1024 units = 1 vCPU). See AWS documentation for valid values."
  type        = string
  default     = "256"
  validation {
    condition     = can(regex("^(256|512|1024|2048|4096|8192|16384)$", var.cpu))
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384."
  }
}

variable "memory" {
  description = "Memory allocation for the task (in MiB). Must be compatible with CPU value."
  type        = string
  default     = "512"
  validation {
    condition     = can(regex("^(512|1024|2048|3072|4096|5120|6144|7168|8192|16384|32768)$", var.memory))
    error_message = "Memory must be a valid ECS memory value (e.g., 512, 1024, 2048, etc.)."
  }
}

variable "desired_count" {
  description = "Number of tasks to run initially. For production, consider setting this higher than 1 for redundancy."
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count >= 0
    error_message = "Desired count must be 0 or greater."
  }
}

variable "deployment_max_percent" {
  description = "Maximum percentage of tasks that can be running during a deployment"
  type        = number
  default     = 200
  validation {
    condition     = var.deployment_max_percent >= 100 && var.deployment_max_percent <= 200
    error_message = "Deployment max percent must be between 100 and 200."
  }
}

variable "deployment_min_percent" {
  description = "Minimum percentage of healthy tasks that must be maintained during a deployment"
  type        = number
  default     = 50
  validation {
    condition     = var.deployment_min_percent >= 0 && var.deployment_min_percent <= 100
    error_message = "Deployment min percent must be between 0 and 100."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days. Consider longer retention for production environments."
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be one of the standard CloudWatch retention periods."
  }
}

variable "environment_variables" {
  description = "Environment variables for the container. Use secrets for sensitive data."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secrets for the container from AWS Secrets Manager or SSM Parameter Store"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

# Auto scaling configuration
variable "enable_autoscaling" {
  description = "Enable application auto scaling for the service. Requires additional IAM permissions."
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks for auto scaling. Should be at least 1 for production environments."
  type        = number
  default     = 1
  validation {
    condition     = var.autoscaling_min_capacity >= 0
    error_message = "Auto scaling min capacity must be 0 or greater."
  }
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for auto scaling. Set based on your application's scaling needs and budget."
  type        = number
  default     = 10
  validation {
    condition     = var.autoscaling_max_capacity >= 0
    error_message = "Auto scaling max capacity must be 0 or greater."
  }
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for auto scaling (0-100)"
  type        = number
  default     = 70
  validation {
    condition     = var.autoscaling_cpu_target >= 0 && var.autoscaling_cpu_target <= 100
    error_message = "CPU target must be between 0 and 100."
  }
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization percentage for auto scaling (0-100)"
  type        = number
  default     = 80
  validation {
    condition     = var.autoscaling_memory_target >= 0 && var.autoscaling_memory_target <= 100
    error_message = "Memory target must be between 0 and 100."
  }
}

# Networking and security
variable "vpc_id" {
  description = "VPC ID where the ECS service will be deployed. Required for network configuration."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS service. Required for network configuration."
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to tasks. Set to false for private subnets."
  type        = bool
  default     = false
}

variable "task_role_arn" {
  description = "ARN of IAM role for tasks to assume. If not provided, a default role will be created."
  type        = string
  default     = null
}

variable "execution_role_arn" {
  description = "ARN of IAM role for ECS task execution. If not provided, a default role will be created."
  type        = string
  default     = null
}

# Health check and grace period
variable "health_check_grace_period_seconds" {
  description = "Grace period in seconds for health checks to stabilize before failing a deployment"
  type        = number
  default     = 60
  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 1800
    error_message = "Health check grace period must be between 0 and 1800 seconds."
  }
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}