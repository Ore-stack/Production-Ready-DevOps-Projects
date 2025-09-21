# Module outputs for ECS cluster and related resources
# These outputs allow other Terraform configurations to access important attributes of the created resources

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  # Using .arn attribute instead of .id for consistency with other ARN outputs
  value       = aws_ecs_service.app.arn
}

output "task_definition_arn" {
  description = "Full ARN of the task definition (including revision)"
  value       = aws_ecs_task_definition.app.arn
}

output "task_definition_family" {
  description = "Family name of the task definition (without revision)"
  value       = aws_ecs_task_definition.app.family
}

output "task_definition_revision" {
  description = "Revision number of the task definition"
  value       = aws_ecs_task_definition.app.revision
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for application logs"
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.arn
}

output "security_group_id" {
  description = "ID of the security group for ECS tasks"
  value       = aws_security_group.app.id
}

output "security_group_arn" {
  description = "ARN of the security group for ECS tasks"
  value       = aws_security_group.app.arn
}

output "execution_role_arn" {
  description = "ARN of the IAM execution role for ECS tasks"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "execution_role_name" {
  description = "Name of the IAM execution role for ECS tasks"
  value       = aws_iam_role.ecs_execution_role.name
}

output "task_role_arn" {
  description = "ARN of the IAM task role (if defined)"
  value       = try(aws_iam_role.ecs_task_role[0].arn, null)
}

output "task_role_name" {
  description = "Name of the IAM task role (if defined)"
  value       = try(aws_iam_role.ecs_task_role[0].name, null)
}

output "service_discovery_namespace" {
  description = "ARN of the Cloud Map service discovery namespace (if enabled)"
  value       = try(aws_service_discovery_service.app[0].arn, null)
}

# Additional useful outputs that consumers might need
output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "service_registry_arn" {
  description = "ARN of the service registry entry (if service discovery is enabled)"
  value       = try(aws_service_discovery_service.app[0].arn, null)
}