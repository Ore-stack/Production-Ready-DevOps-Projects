#!/bin/bash
# Clean up all Terraform-managed environments

set -e

echo "🧹 Cleaning up all environments"
echo "==============================="
echo ""
echo "⚠️  WARNING: This will DESTROY all Terraform-managed resources!"
echo "This includes:"
echo "- ECS clusters and services"
echo "- Load balancers and target groups"
echo "- CloudWatch log groups"
echo "- IAM roles and policies"
echo "- Security groups and networking resources"
echo "- All application data and logs"
echo ""
echo "This action is IRREVERSIBLE!"
echo ""

# Confirm destruction
read -rp "Are you absolutely sure you want to continue? (type 'destroy' to confirm): " response
if [[ "$response" != "destroy" ]]; then
    echo "❌ Cleanup cancelled"
    exit 0
fi

echo ""
echo "🚨 PROCEEDING WITH DESTRUCTION IN 10 SECONDS..."
echo "Press Ctrl+C to abort now!"
sleep 10

# Function to destroy environment
destroy_environment() {
    local env_name=$1
    local env_path=$2
    
    echo ""
    echo "🗑️  Destroying $env_name environment..."
    
    if [ -d "$env_path" ] && [ -f "$env_path/terraform.tfstate" ] || [ -f "$env_path/terraform.tfstate.backup" ]; then
        cd "$env_path" || exit 1
        
        # Initialize Terraform if not already initialized
        if [ ! -d ".terraform" ]; then
            echo "📦 Initializing Terraform for $env_name..."
            terraform init -reconfigure > /dev/null 2>&1
        fi
        
        # Destroy resources
        echo "🔥 Destroying $env_name resources..."
        terraform destroy -auto-approve -input=false
        echo "✅ $env_name environment destroyed"
        
        cd - > /dev/null || exit 1
    else
        echo "ℹ️  No $env_name environment found (no Terraform state)"
    fi
}

# Cleanup development
destroy_environment "development" "environments/dev"

# Cleanup production  
destroy_environment "production" "environments/prod"

# Cleanup any global infrastructure
if [ -d "global" ]; then
    destroy_environment "global" "global"
fi

echo ""
echo "================================="
echo "🎉 All environments cleaned up!"
echo ""
echo "Next steps:"
echo "1. Verify in AWS Console that all resources are deleted"
echo "2. Check for any orphaned resources (manual cleanup may be needed)"
echo "3. Remove any local Terraform files if desired:"
echo "   find . -name '.terraform*' -exec rm -rf {} + 2>/dev/null || true"
echo "   find . -name 'terraform.tfstate*' -exec rm -f {} +"
echo ""
echo "⚠️  Note: Some resources like S3 buckets with data may require manual cleanup"