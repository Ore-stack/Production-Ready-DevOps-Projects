# Development environment variables
# These variables define the configuration for the development environment

variable "app_name" {
  description = "Application name used for resource naming and tagging. Should be unique across environments."
  type        = string
  validation {
    condition     = length(var.app_name) >= 2 && length(var.app_name) <= 32
    error_message = "App name must be between 2 and 32 characters."
  }
}

variable "aws_region" {
  description = "AWS region where development resources will be deployed. Choose a region close to your development team."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1, eu-west-1)."
  }
}

variable "container_image" {
  description = "Docker image URI to run in development. For development, this is often a local build or latest tag."
  type        = string
  validation {
    condition     = can(regex("^[^:]+:[^:]+$", var.container_image)) || can(regex("^\\d+\\.dkr\\.ecr\\.\\w+-\\w+-\\d+\\.amazonaws\\.com/", var.container_image))
    error_message = "Container image must be in format 'repository:tag' or ECR URI format."
  }
}

variable "container_port" {
  description = "Port the container application listens on. This should match the port exposed in your Dockerfile."
  type        = number
  default     = 3000
  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "environment" {
  description = "Environment name. Used for resource tagging and naming. Defaults to 'dev' for development."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "development", "test"], lower(var.environment))
    error_message = "Environment must be one of: dev, development, test for development environments."
  }
}

# Development-specific optional variables
variable "vpc_id" {
  description = "VPC ID for the development environment. If not provided, the default VPC will be used."
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for development environment. Required for public internet access."
  type        = list(string)
  default     = []
}

variable "extra_environment_variables" {
  description = "Additional environment variables for development and testing purposes."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to all development resources for cost tracking and management."
  type        = map(string)
  default     = {}
}

variable "enable_public_access" {
  description = "Whether to assign public IP addresses to development tasks for easier access and testing."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period for development logs. Shorter retention reduces costs."
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "Log retention must be one of: 1, 3, 5, 7, 14, 30 days for development."
  }
}

variable "desired_count" {
  description = "Number of tasks to run in development. Typically 1 for cost efficiency."
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 2
    error_message = "Desired count must be between 0 and 2 for development environments."
  }
}