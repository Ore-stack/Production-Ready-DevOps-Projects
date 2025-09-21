# Reusable ECS Fargate Webapp Module
# This module creates a complete ECS Fargate deployment with logging, security, and optional autoscaling

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources to reference existing AWS resources
data "aws_vpc" "default" {
  default = true # Uses the default VPC; consider making this configurable for production
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# CloudWatch Log Group for centralized container logging
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.environment}-${var.app_name}" # Standard naming convention
  retention_in_days = var.log_retention_days # Configurable retention period

  tags = {
    Name        = "${var.environment}-${var.app_name}-logs"
    Environment = var.environment
    Project     = var.app_name
    ManagedBy   = "Terraform" # Good practice for infrastructure management tracking
  }
}

# IAM Role for ECS Task Execution - allows ECS to pull images, manage logs, etc.
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.environment}-${var.app_name}-execution-role" # Descriptive role name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com" # Trust relationship for ECS tasks
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-${var.app_name}-execution-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Attach the standard AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster - logical grouping of tasks and services
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.app_name}-cluster" # Environment-specific cluster name

  # Optional: Enable container insights for enhanced monitoring
  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${var.environment}-${var.app_name}-cluster"
    Environment = var.environment
    Project     = var.app_name
    ManagedBy   = "Terraform"
  }
}

# Security Group for the application - controls inbound/outbound traffic
resource "aws_security_group" "app" {
  name        = "${var.environment}-${var.app_name}-sg"
  description = "Security group for ${var.environment} ${var.app_name} ECS service"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule - allow traffic to the container port
  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this in production
    description = "Allow inbound traffic to application port"
  }

  # Egress rule - allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-${var.app_name}-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ECS Task Definition - blueprint for your application container
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.environment}-${var.app_name}" # Family name for versioning
  network_mode             = "awsvpc" # Required for Fargate
  requires_compatibilities = ["FARGATE"] # Specify Fargate launch type
  cpu                      = var.cpu # CPU units (1024 = 1 vCPU)
  memory                   = var.memory # Memory in MB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  # Container definitions - main application container
  container_definitions = jsonencode([
    {
      name  = var.app_name
      image = var.container_image # Container image from ECR or Docker Hub
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      # Environment variables - combine default and custom variables
      environment = concat(
        [
          {
            name  = "ENVIRONMENT"
            value = var.environment
          },
          {
            name  = "APP_NAME"
            value = var.app_name
          },
          {
            name  = "PORT"
            value = tostring(var.container_port)
          }
        ],
        var.environment_variables
      )
      # Logging configuration - send logs to CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # Health check - ensure container is healthy
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60 # Grace period for container startup
      }
      # Resource limits - prevent container from consuming excessive resources
      cpu    = var.cpu
      memory = var.memory
    }
  ])

  tags = {
    Name        = "${var.environment}-${var.app_name}-task"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ECS Service - maintains the desired number of running tasks
resource "aws_ecs_service" "app" {
  name            = "${var.environment}-${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count # Number of tasks to run
  launch_type     = "FARGATE"

  # Network configuration - VPC networking for tasks
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true # Required for internet access; consider false for private subnets
  }

  # Deployment circuit breaker - automatic rollback on deployment failures
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Optional: Load balancer integration
  dynamic "load_balancer" {
    for_each = var.load_balancer_arn != null ? [1] : []
    content {
      target_group_arn = var.load_balancer_target_group_arn
      container_name   = var.app_name
      container_port   = var.container_port
    }
  }

  tags = {
    Name        = "${var.environment}-${var.app_name}-service"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Ensure task definition is created before service
  depends_on = [aws_ecs_task_definition.app]
}

# Application Auto Scaling Target - defines scalable resource
resource "aws_appautoscaling_target" "ecs_target" {
  count              = var.enable_autoscaling ? 1 : 0 # Conditional creation
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  # Ensure service is created before setting up autoscaling
  depends_on = [aws_ecs_service.app]
}

# CPU-based Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.environment}-${var.app_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling" # Simple scaling based on metric
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = 300 # 5 minutes cooldown for scale-in
    scale_out_cooldown = 60  # 1 minute cooldown for scale-out
  }

  depends_on = [aws_appautoscaling_target.ecs_target]
}

# Memory-based Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.environment}-${var.app_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_memory_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }

  depends_on = [aws_appautoscaling_target.ecs_target]
}

# CloudWatch Dashboard for monitoring (optional)
resource "aws_cloudwatch_dashboard" "ecs_dashboard" {
  count          = var.enable_cloudwatch_dashboard ? 1 : 0
  dashboard_name = "${var.environment}-${var.app_name}-dashboard"

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
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.app.name, "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service CPU and Memory Utilization"
        }
      }
    ]
  })

  depends_on = [aws_ecs_service.app]
}
