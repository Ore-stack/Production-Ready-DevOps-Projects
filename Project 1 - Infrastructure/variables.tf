# variables.tf - Define customizable settings for ECS Cluster deployment

# ==============================================================================
# REQUIRED VARIABLES (Consider making these required for production environments)
# ==============================================================================

# variable "cluster_name" {
#   description = "The unique name for the ECS Cluster"
#   type        = string
#   validation {
#     condition     = length(var.cluster_name) >= 3 && length(var.cluster_name) <= 32
#     error_message = "Cluster name must be between 3 and 32 characters."
#   }
# }

# variable "Environment" {
#   description = "The deployment environment (dev, staging, prod)"
#   type        = string
#   validation {
#     condition     = contains(["dev", "staging", "prod"], var.Environment)
#     error_message = "Environment must be one of: dev, staging, prod."
#   }
# }

# ==============================================================================
# OPTIONAL VARIABLES WITH DEFAULTS
# ==============================================================================

variable "region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
  
  # Validation example (uncomment if needed)
  # validation {
  #   condition     = contains(["us-east-1", "us-west-2", "eu-west-1"], var.region)
  #   error_message = "Region must be a supported AWS region."
  # }
}

variable "vpc_id" {
  description = "VPC ID to use"
  type        = string
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

variable "cluster_name" {
  description = "The name for the ECS Cluster"
  type        = string
  default     = "my-devops-cluster"
}

variable "environment" {
  description = "The Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "container_name" {
  description = "Name of the container (for identification purposes)"
  type        = string
  default     = "nginx-app"
}

variable "container_image" {
  description = "Docker image to run (repository:tag format)"
  type        = string
  default     = "nginx:latest"
}

# ==============================================================================
# ADDITIONAL RECOMMENDED VARIABLES (Uncomment as needed)
# ==============================================================================

# variable "vpc_cidr" {
#   description = "CIDR block for the VPC"
#   type        = string
#   default     = "10.0.0.0/16"
# }

# variable "public_subnet_cidrs" {
#   description = "List of CIDR blocks for public subnets"
#   type        = list(string)
#   default     = ["10.0.1.0/24", "10.0.2.0/24"]
# }

# variable "private_subnet_cidrs" {
#   description = "List of CIDR blocks for private subnets"
#   type        = list(string)
#   default     = ["10.0.3.0/24", "10.0.4.0/24"]
# }

# variable "instance_type" {
#   description = "EC2 instance type for ECS container instances"
#   type        = string
#   default     = "t3.micro"
# }

# variable "desired_count" {
#   description = "Number of ECS tasks to run"
#   type        = number
#   default     = 1
# }

# variable "container_port" {
#   description = "Port that the container listens on"
#   type        = number
#   default     = 80
# }

# variable "host_port" {
#   description = "Port on the host to map to container port"
#   type        = number
#   default     = 80
# }

# ==============================================================================
# TAGGING VARIABLES (Recommended for cost tracking and organization)
# ==============================================================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "devops-cluster"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}

# variable "additional_tags" {
#   description = "Additional tags to apply to resources"
#   type        = map(string)
#   default     = {}
# }