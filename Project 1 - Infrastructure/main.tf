# -------------------------------------------------------------------
# Terraform Configuration: Specifies required version and providers
# -------------------------------------------------------------------
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -------------------------------------------------------------------
# AWS Provider Configuration: Region is passed as a variable
# -------------------------------------------------------------------
provider "aws" {
  region = var.region
}

# -------------------------------------------------------------------
# Data Source: Fetches the default VPC (useful for quick setups)
# -------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# -------------------------------------------------------------------
# Data Source: Retrieves subnets associated with the default VPC
# -------------------------------------------------------------------
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -------------------------------------------------------------------
# ECS Cluster: Logical container for ECS services and tasks
# -------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
    Project     = "my-aws-devops-infrastructure"
  }
}

# -------------------------------------------------------------------
# CloudWatch Log Group: Stores logs from ECS containers
# -------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "webapp" {
  name              = "/ecs/${var.cluster_name}-webapp"
  retention_in_days = 7

  tags = {
    Name        = "${var.cluster_name}-webapp-logs"
    Environment = var.environment
  }
}

# -------------------------------------------------------------------
# IAM Role: Execution role for ECS tasks to interact with AWS services
# -------------------------------------------------------------------
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.cluster_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ecs-execution-role"
    Environment = var.environment
  }
}

# -------------------------------------------------------------------
# IAM Policy Attachment: Grants ECS execution role necessary permissions
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -------------------------------------------------------------------
# Security Group: Controls inbound/outbound traffic for ECS tasks
# -------------------------------------------------------------------
resource "aws_security_group" "webapp_sg" {
  name        = "${var.cluster_name}-webapp-sg"
  description = "Security group for web application"
  vpc_id      = data.aws_vpc.default.id

  # Inbound Rule: Allow HTTP traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-webapp-sg"
    Environment = var.environment
  }
}

# -------------------------------------------------------------------
# ECS Task Definition: Blueprint for running the container
# -------------------------------------------------------------------
resource "aws_ecs_task_definition" "webapp" {
  family                   = "${var.cluster_name}-webapp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  # Container Definition: Encoded as JSON
  container_definitions = jsonencode([
    {
      name  = "webapp"
      image = var.container_image

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.webapp.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.cluster_name}-webapp-task"
    Environment = var.environment
  }
}

# -------------------------------------------------------------------
# ECS Service: Runs and maintains the desired number of tasks
# -------------------------------------------------------------------
resource "aws_ecs_service" "webapp" {
  name            = "${var.cluster_name}-webapp-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webapp.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.webapp_sg.id]
    assign_public_ip = true
  }

  tags = {
    Name        = "${var.cluster_name}-webapp-service"
    Environment = var.environment
  }
}