#!/bin/bash
# Deploy to development environment

set -e

echo "🚀 Deploying to Development Environment"
echo "======================================"

# Configuration
ENV_DIR="environments/dev"
TF_PLAN="dev.tfplan"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Check if environment directory exists
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ Environment directory '$ENV_DIR' not found"
    exit 1
fi

cd "$ENV_DIR"

# Check if AWS CLI is configured and has necessary permissions
echo "🔐 Checking AWS credentials and permissions..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Verify AWS permissions
if ! aws iam get-user >/dev/null 2>&1; then
    echo "❌ AWS credentials lack necessary IAM permissions"
    exit 1
fi

echo "✅ AWS CLI configured with valid credentials"

# Initialize Terraform if not already initialized
if [ ! -d ".terraform" ]; then
    echo "📦 Initializing Terraform..."
    terraform init -input=false
else
    echo "🔄 Reinitializing Terraform..."
    terraform init -input=false -reconfigure
fi

# Validate Terraform configuration
echo "🔍 Validating Terraform configuration..."
if ! terraform validate; then
    echo "❌ Terraform configuration validation failed"
    exit 1
fi

echo "✅ Configuration validated successfully"

# Format Terraform code
echo "💅 Formatting Terraform code..."
terraform fmt -recursive

# Plan the deployment
echo "📋 Creating deployment plan..."
if ! terraform plan -out="$TF_PLAN" -input=false; then
    echo "❌ Terraform plan failed"
    exit 1
fi

echo ""
echo "======================================"
echo "⚠️   REVIEW DEPLOYMENT PLAN ABOVE   ⚠️"
echo "======================================"
echo ""
echo "This plan will:"
echo "• Create/modify/destroy resources in AWS"
echo "• Impact the development environment"
echo "• Potentially incur costs"
echo ""
read -rp "Do you want to proceed with deployment? (type 'deploy' to confirm): " response

if [[ "$response" != "deploy" ]]; then
    echo "❌ Deployment cancelled"
    echo "💡 To review plan again: terraform show $TF_PLAN"
    exit 0
fi

# Apply the deployment
echo "🏗️  Deploying to development environment..."
if ! terraform apply -input=false "$TF_PLAN"; then
    echo "❌ Deployment failed"
    echo "🔧 Check the error messages above and fix issues"
    exit 1
fi

# Clean up plan file
rm -f "$TF_PLAN"

echo ""
echo "======================================"
echo "🎉 DEVELOPMENT DEPLOYMENT COMPLETE!"
echo "======================================"

# Show outputs and next steps
echo ""
echo "📊 Deployment Outputs:"
terraform output

echo ""
echo "🔗 Quick Links:"
terraform output console_urls 2>/dev/null || echo "No console URLs available"

echo ""
echo "📋 Next Steps:"
terraform output next_steps 2>/dev/null || echo "No next steps defined"

echo ""
echo "💡 Tips:"
echo "• Run 'terraform output' to see all outputs"
echo "• Run 'terraform state list' to see deployed resources"
echo "• Monitor deployment in AWS Console"

cd ../..