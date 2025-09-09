### 🚀 Project 1: Infrastructure as Code (AWS)

Create your AWS infrastructure using **Terraform** and **ECS Fargate**.

## 🌐 What This Creates

- ECS Fargate cluster (serverless containers)
- ECS service running Nginx web server
- CloudWatch log group for monitoring
- Security group for network access
- IAM roles for proper permissions

## 🧰 Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- [Terraform](https://www.terraform.io/downloads.html) installed (v1.0+ recommended)
- AWS account with appropriate permissions (Free Tier eligible)

## 🛠 Step-by-Step Deployment

### ✅ Step 1: Set Up AWS CLI

```bash
# macOS
brew install awscli

# Linux (Ubuntu/Debian)
sudo apt update && sudo apt install awscli

# Windows
# Download from: https://aws.amazon.com/cli/

# Configure AWS credentials (use IAM user credentials, not root account)
aws configure
# Provide Access Key, Secret Key, region (e.g., us-east-1), output format (e.g., json)

# Verify authentication
aws sts get-caller-identity
```

### ✅ Step 2: Customize Your Settings

Update the `terraform.tfvars` file with your unique configuration:

```hcl
cluster_name = "yourname-devops-cluster"  # Replace "yourname" with your identifier
region       = "us-east-1"                # Preferred AWS region
```

### ✅ Step 3: Deploy Infrastructure

```bash
# Initialize Terraform and download providers
terraform init

# Review planned changes (safety check)
terraform plan

# Apply the configuration (will take 5-10 minutes)
terraform apply

# Confirm with 'yes' when prompted
```

### ✅ Step 4: Get the Public IP

After deployment completes, retrieve your application's public IP:

```bash
# Method 1: Using Terraform outputs (if configured)
terraform output public_ip

# Method 2: Using AWS CLI (if outputs not configured)
CLUSTER_NAME=$(terraform output -raw cluster_name)
SERVICE_NAME=$(terraform output -raw service_name)

# One-liner to get public IP
aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --query 'taskArns[0]' --output text) \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text | \
  xargs -I {} aws ec2 describe-network-interfaces \
  --network-interface-ids {} \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text
```

### ✅ Step 5: Test Your Application

1. Copy the public IP from the previous step
2. Open it in your web browser: `http://<PUBLIC_IP>`
3. You should see the **Nginx Welcome Page**

> ⏱️ Note: It may take 2-3 minutes after deployment for the application to become available

### ✅ Step 6: View Logs in CloudWatch

```bash
LOG_GROUP=$(terraform output -raw log_group_name)

# View available log streams
aws logs describe-log-streams --log-group-name $LOG_GROUP --order-by LastEventTime --descending

# View recent logs (replace with your stream name)
aws logs get-log-events --log-group-name $LOG_GROUP --log-stream-name <stream_name> --limit 10
```

## 🐞 Troubleshooting

### ❌ Error: `NoCredentialsError` or Unable to locate credentials
- Run `aws configure` to set up credentials
- Verify with `aws sts get-caller-identity`
- Check that AWS credentials are not expired

### ❌ Error: `UnauthorizedOperation`
- Ensure your IAM user has appropriate permissions (AdministratorAccess recommended for learning)
- Verify ECS, EC2, IAM, and CloudWatch permissions are present

### ❌ Task Stopping or Failing
- Check CloudWatch logs for errors
- Verify container image is accessible: `nginx:alpine`
- Ensure CPU/memory values are appropriate for Fargate

### ❌ Website Not Loading
- Wait 2-3 minutes for application to start
- Confirm public IP is assigned (check EC2 console > Network Interfaces)
- Verify security group allows inbound traffic on port 80

### ❌ Error: `ResourceAlreadyExistsException`
- Use a unique cluster name in `terraform.tfvars`
- Destroy existing infrastructure: `terraform destroy`

### ❌ Terraform Provider Errors
- Run `terraform init` to ensure all providers are properly downloaded
- Verify Terraform version compatibility

## 🧹 Clean Up (Important!)

To avoid unexpected AWS charges, always clean up when finished:

```bash
# Destroy all created resources
terraform destroy

# Confirm with 'yes' when prompted
```

**Verify in AWS Console** that all resources have been terminated:
- ECS Cluster and Services
- CloudWatch Log Groups
- IAM Roles (if not used elsewhere)
- Network Interfaces

## 🎓 What You Learned

✅ Infrastructure as Code principles with Terraform  
✅ AWS ECS Fargate (serverless containers) deployment  
✅ IAM Roles & Permissions management  
✅ Security Groups & VPC networking configuration  
✅ CloudWatch Logging for monitoring  
✅ AWS CLI commands for resource management  

## 🔄 Next Steps

- Modify the Docker image to deploy a custom application
- Add a custom domain with Route53 and Application Load Balancer
- Implement CI/CD pipeline for automated deployments
- Move on to **Project 2: Automated Deployment Pipeline**

## 📚 Additional Resources

- [Terraform ECS Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)
- [AWS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
