#!/bin/bash
# Deploy to production environment

set -e

echo "🚀 Deploying to Production Environment"
echo "====================================="
echo ""
echo "⚠️  WARNING: PRODUCTION DEPLOYMENT"
echo "====================================="
echo "This will:"
echo "• Deploy to LIVE production environment"
echo "• Impact real users and traffic"
echo "• Potentially incur significant costs"
echo "• Make irreversible changes to infrastructure"
echo ""
echo "Prerequisites:"
echo "✅ Thorough testing in development environment"
echo "✅ Code review and approval"
echo "✅ Backup of current production state"
echo "✅ Maintenance window scheduled (if needed)"
echo ""

# Configuration
ENV_DIR="environments/prod"
TF_PLAN="prod-$(date +%Y%m%d-%H%M%S).tfplan"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Validate environment directory
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ Production environment directory '$ENV_DIR' not found"
    exit 1
fi

cd "$ENV_DIR"

# First confirmation
read -rp "Do you want to proceed with PRODUCTION deployment? (type 'confirm' to continue): " response
if [[ "$response" != "confirm" ]]; then
    echo "❌ Production deployment cancelled"
    exit 0
fi

echo ""
echo "🔐 Checking AWS credentials and permissions..."

# Verify AWS credentials and production access
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Verify production-level permissions
if ! aws iam simulate-principal-policy \
    --policy-source-arn "$(aws sts get-caller-identity --query Arn --output text)" \
    --action-names "ecs:UpdateService" "autoscaling:UpdateAutoScalingGroup" \
    --output text 2>/dev/null | grep -q "allowed"; then
    echo "❌ Insufficient AWS permissions for production deployment"
    exit 1
fi

echo "✅ AWS credentials validated with production permissions"

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init -input=false -reconfigure

# Validate configuration
echo "🔍 Validating production configuration..."
if ! terraform validate; then
    echo "❌ Production configuration validation failed"
    exit 1
fi

echo "✅ Configuration validated"

# Format code
terraform fmt -recursive

# Plan deployment
echo "📋 Creating production deployment plan..."
if ! terraform plan -out="$TF_PLAN" -input=false; then
    echo "❌ Production plan failed"
    exit 1
fi

echo ""
echo "====================================="
echo "🚨 PRODUCTION DEPLOYMENT PLAN REVIEW"
echo "====================================="
echo ""
echo "This plan will affect LIVE PRODUCTION environment:"
echo "• Real users and traffic"
echo "• Business-critical systems"
echo "• Financial costs"
echo ""
echo "Plan file: $TF_PLAN"
echo "Generated: $TIMESTAMP"
echo ""

# Final confirmation
read -rp "FINAL CONFIRMATION: Type 'DEPLOY PRODUCTION' to proceed: " response
if [[ "$response" != "DEPLOY PRODUCTION" ]]; then
    echo "❌ Production deployment cancelled"
    echo "💡 Plan saved as $TF_PLAN for review"
    exit 0
fi

echo ""
echo "⏰ Starting production deployment in 10 seconds..."
echo "Press Ctrl+C to ABORT now!"
for i in {10..1}; do
    echo -n "$i... "
    sleep 1
done
echo ""
echo "🏗️  Deploying to PRODUCTION..."

# Apply deployment
if ! terraform apply -input=false "$TF_PLAN"; then
    echo "❌ PRODUCTION DEPLOYMENT FAILED!"
    echo "🚨 Immediate action required!"
    echo "💡 Check AWS Console and logs for issues"
    exit 1
fi

# Cleanup plan file
rm -f "$TF_PLAN"

echo ""
echo "====================================="
echo "🎉 PRODUCTION DEPLOYMENT SUCCESSFUL!"
echo "====================================="
echo ""

# Show outputs
echo "📊 Production Outputs:"
terraform output

echo ""
echo "🔗 Production Console URLs:"
terraform output console_urls 2>/dev/null || echo "No console URLs available"

echo ""
echo "📋 Next Steps:"
terraform output next_steps 2>/dev/null || echo "No next steps defined"

echo ""
echo "👀 Monitoring Recommendations:"
echo "• Immediately verify application health: terraform output lb_dns_name"
echo "• Monitor CloudWatch metrics for 15 minutes"
echo "• Check ECS service stability in AWS Console"
echo "• Watch for auto-scaling events"
echo "• Validate all endpoints and functionality"

# Save deployment log
echo "[$TIMESTAMP] Production deployment completed successfully" >> deploy.log

cd ../..