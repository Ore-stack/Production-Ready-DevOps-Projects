# Production environment outputs

output "environment" {
  description = "Environment name"
  value       = "prod"
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.webapp.cluster_name
}

output "service_name" {
  description = "ECS service name"
  value       = module.webapp.service_name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.webapp.log_group_name
}

output "autoscaling_enabled" {
  description = "Auto scaling status"
  value       = "enabled"
}

output "lb_dns_name" {
  description = "Load Balancer DNS name"
  value       = module.webapp.lb_dns_name
}

output "console_urls" {
  description = "AWS console URLs for quick access"
  value = {
    ecs_cluster = "https://${var.aws_region}.console.aws.amazon.com/ecs/v2/clusters/${module.webapp.cluster_name}/services?region=${var.aws_region}"
    logs        = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(module.webapp.log_group_name, "/", "$252F")}"
    autoscaling = "https://${var.aws_region}.console.aws.amazon.com/ecs/v2/clusters/${module.webapp.cluster_name}/services/${module.webapp.service_name}/auto-scaling?region=${var.aws_region}"
    load_balancer = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#LoadBalancers:"
  }
}

output "next_steps" {
  description = "Recommended actions after deployment"
  value = <<EOT
🚀 Production environment deployed successfully!

📊 Key Features:
• 2+ instances running with auto-scaling (2-10 instances)
• 30-day CloudWatch log retention
• Production-optimized resource allocation
• High availability across multiple AZs

🔍 Next Steps:
1. Test application: http://${module.webapp.lb_dns_name}
2. Monitor ECS cluster: ${self.console_urls.ecs_cluster}
3. Check auto-scaling: ${self.console_urls.autoscaling}
4. View logs: ${self.console_urls.logs}
5. Verify load balancer: ${self.console_urls.load_balancer}

✅ Production Best Practices Enabled:
• Multiple instances for high availability
• Auto-scaling based on CPU/memory utilization
• Blue/green deployment strategy
• Extended log retention for debugging
• Health checks and grace periods
• Secure networking configuration
EOT
}