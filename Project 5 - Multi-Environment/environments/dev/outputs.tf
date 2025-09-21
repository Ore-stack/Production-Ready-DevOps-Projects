# Development environment outputs
# These outputs provide useful information for developers after deployment

variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
}

variable "app_name" {
  description = "Application name used for resource identification"
  type        = string
}

# Environment identification
output "environment" {
  description = "Environment name"
  value       = "dev"
}

# Core infrastructure outputs
output "cluster_name" {
  description = "ECS cluster name"
  value       = module.webapp.cluster_name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.webapp.cluster_arn
}

output "service_name" {
  description = "ECS service name"
  value       = module.webapp.service_name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = module.webapp.service_arn
}

output "task_definition_arn" {
  description = "Task definition ARN (including revision)"
  value       = module.webapp.task_definition_arn
}

# Monitoring and logging outputs
output "log_group_name" {
  description = "CloudWatch log group name for application logs"
  value       = module.webapp.log_group_name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = module.webapp.log_group_arn
}

# Networking outputs (if available from module)
output "security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = try(module.webapp.security_group_id, null)
}

output "load_balancer_dns" {
  description = "Load balancer DNS name (if configured)"
  value       = try(module.webapp.load_balancer_dns, null)
}

# IAM outputs
output "execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = try(module.webapp.execution_role_arn, null)
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = try(module.webapp.task_role_arn, null)
}

# Console URLs for easy access
output "console_urls" {
  description = "AWS Management Console URLs for quick access to resources"
  value = {
    ecs_cluster     = "https://${var.aws_region}.console.aws.amazon.com/ecs/v2/clusters/${module.webapp.cluster_name}/services?region=${var.aws_region}"
    cloudwatch_logs = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(module.webapp.log_group_name, "/", "$252F")}"
    ecs_service     = "https://${var.aws_region}.console.aws.amazon.com/ecs/v2/clusters/${module.webapp.cluster_name}/services/${module.webapp.service_name}/details?region=${var.aws_region}"
    task_definitions = "https://${var.aws_region}.console.aws.amazon.com/ecs/v2/task-definitions/${module.webapp.task_definition_family}?region=${var.aws_region}"
    security_groups  = try("https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#SecurityGroup:groupId=${module.webapp.security_group_id}", null)
  }
}

# CLI commands for common operations
output "cli_commands" {
  description = "Useful AWS CLI commands for development"
  value = {
    view_tasks = "aws ecs list-tasks --cluster ${module.webapp.cluster_name} --service-name ${module.webapp.service_name} --region ${var.aws_region}"
    describe_service = "aws ecs describe-services --cluster ${module.webapp.cluster_name} --services ${module.webapp.service_name} --region ${var.aws_region}"
    view_logs = "aws logs tail ${module.webapp.log_group_name} --region ${var.aws_region} --since 5m"
    restart_service = "aws ecs update-service --cluster ${module.webapp.cluster_name} --service ${module.webapp.service_name} --force-new-deployment --region ${var.aws_region}"
    get_task_ips = "aws ecs describe-tasks --cluster ${module.webapp.cluster_name} --tasks $(aws ecs list-tasks --cluster ${module.webapp.cluster_name} --service-name ${module.webapp.service_name} --region ${var.aws_region} --query 'taskArns' --output text) --region ${var.aws_region} --query 'tasks[].attachments[].details[?name==\\\"privateIPv4Address\\\"].value' --output text"
  }
}

# Local values for URL construction
locals {
  console_urls = {
    ecs_cluster     = "https://${var.aws_region}.console.aws.amazon.com/ecs/v2/clusters/${module.webapp.cluster_name}/services?region=${var.aws_region}"
    cloudwatch_logs = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(module.webapp.log_group_name, "/", "$252F")}"
    ecs_service     = "https://${var.aws_region}.console.aws.amazon.com/ecs/v2/clusters/${module.webapp.cluster_name}/services/${module.webapp.service_name}/details?region=${var.aws_region}"
  }
}

# Comprehensive next steps guidance
output "next_steps" {
  description = "Development environment deployment guide and next steps"
  value = <<EOF
🎉 Development environment deployed successfully!

📊 Monitoring:
- ECS Console: ${local.console_urls.ecs_cluster}
- Service Details: ${local.console_urls.ecs_service}
- Application Logs: ${local.console_urls.cloudwatch_logs}

🔧 Common CLI Commands:
- View running tasks: ${outputs.cli_commands.view_tasks}
- Stream logs: ${outputs.cli_commands.view_logs}
- Restart service: ${outputs.cli_commands.restart_service}

🚀 Testing your application:
${local.load_balancer_dns != null ? "Load balancer URL: http://" + local.load_balancer_dns : "Get task IPs: " + outputs.cli_commands.get_task_ips}

📝 Development workflow:
1. Code changes trigger CI/CD pipeline
2. New Docker image is built and pushed to ECR
3. ECS service is updated with new task definition
4. Monitor deployment in ECS console

💡 Tips:
- Use 'aws logs tail' to stream logs during development
- Check task health in ECS console if experiencing issues
- Environment variables and secrets are managed in AWS Parameter Store

To see all outputs: terraform output
EOF
}

# Additional useful outputs
output "deployment_status" {
  description = "Current deployment status summary"
  value = {
    environment    = "dev"
    app_name       = var.app_name
    region         = var.aws_region
    cluster        = module.webapp.cluster_name
    service        = module.webapp.service_name
    task_definition = module.webapp.task_definition_family
    desired_count  = module.webapp.desired_count
    deployed_at    = timestamp()
  }
}