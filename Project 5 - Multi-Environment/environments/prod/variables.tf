# Production environment variables

variable "app_name" {
  description = "Application name (e.g., 'myapp-prod')"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.app_name))
    error_message = "App name must contain only alphanumeric characters and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-1", "us-west-2", "eu-west-1", "eu-central-1"], var.aws_region)
    error_message = "Invalid AWS region. Must be one of: us-east-1, us-east-2, us-west-1, us-west-2, eu-west-1, eu-central-1."
  }
}

variable "container_image" {
  description = "Docker image to run (e.g., 'nginx:stable' or 'account-id.dkr.ecr.region.amazonaws.com/repo:tag')"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9./:-]+$", var.container_image))
    error_message = "Container image must be a valid Docker image reference."
  }
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "environment" {
  description = "Environment name (e.g., 'prod', 'production')"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["prod", "production"], var.environment)
    error_message = "Environment must be either 'prod' or 'production' for production environments."
  }
}

variable "cpu" {
  description = "CPU units for the task (1024 units = 1 vCPU)"
  type        = number
  default     = 1024
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Memory allocation for the task (in MB)"
  type        = number
  default     = 2048
  validation {
    condition     = var.memory >= 512 && var.memory <= 30720
    error_message = "Memory must be between 512 and 30720 MB."
  }
}

variable "desired_count" {
  description = "Number of tasks to run initially"
  type        = number
  default     = 2
  validation {
    condition     = var.desired_count >= 2 && var.desired_count <= 20
    error_message = "Desired count must be between 2 and 20 for production."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
  validation {
    condition     = contains([7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be one of the standard CloudWatch retention periods."
  }
}

variable "enable_autoscaling" {
  description = "Enable auto scaling for the service"
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 2
  validation {
    condition     = var.autoscaling_min_capacity >= 2 && var.autoscaling_min_capacity <= 10
    error_message = "Minimum capacity must be between 2 and 10."
  }
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 10
  validation {
    condition     = var.autoscaling_max_capacity >= 2 && var.autoscaling_max_capacity <= 50
    error_message = "Maximum capacity must be between 2 and 50."
  }
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.autoscaling_cpu_target >= 50 && var.autoscaling_cpu_target <= 90
    error_message = "CPU target must be between 50% and 90%."
  }
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
  default     = 80
  validation {
    condition     = var.autoscaling_memory_target >= 60 && var.autoscaling_memory_target <= 90
    error_message = "Memory target must be between 60% and 90%."
  }
}

variable "deployment_max_capacity" {
  description = "Maximum percentage of tasks during deployment (blue/green)"
  type        = number
  default     = 150
  validation {
    condition     = var.deployment_max_capacity >= 100 && var.deployment_max_capacity <= 200
    error_message = "Deployment max capacity must be between 100% and 200%."
  }
}

variable "deployment_min_capacity" {
  description = "Minimum percentage of healthy tasks during deployment"
  type        = number
  default     = 75
  validation {
    condition     = var.deployment_min_capacity >= 50 && var.deployment_min_capacity <= 100
    error_message = "Deployment min capacity must be between 50% and 100%."
  }
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must start with 'vpc-'."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets are required for high availability."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}