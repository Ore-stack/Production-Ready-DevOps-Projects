#!/bin/bash
# Get public URLs for all running applications across environments

set -euo pipefail

echo "🔍 Finding application URLs"
echo "=========================="

get_task_ip() {
    local cluster_name=$1
    local service_name=$2
    local env_name=$3
    
    echo "Checking $env_name environment..."
    
    # Get running task ARN
    local task_arn
    task_arn=$(aws ecs list-tasks \
        --cluster "$cluster_name" \
        --service-name "$service_name" \
        --desired-status RUNNING \
        --query 'taskArns[0]' \
        --output text 2>/dev/null || true)
    
    if [[ "$task_arn" == "None" || -z "$task_arn" ]]; then
        echo "❌ No running tasks found in $env_name"
        return 1
    fi
    
    # Get network interface ID
    local network_interface_id
    network_interface_id=$(aws ecs describe-tasks \
        --cluster "$cluster_name" \
        --tasks "$task_arn" \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text 2>/dev/null || true)
    
    if [[ -z "$network_interface_id" || "$network_interface_id" == "None" ]]; then
        echo "❌ Could not get network interface for $env_name"
        return 1
    fi
    
    # Get public IP
    local public_ip
    public_ip=$(aws ec2 describe-network-interfaces \
        --network-interface-ids "$network_interface_id" \
        --query 'NetworkInterfaces[0].Association.PublicIp' \
        --output text 2>/dev/null || true)
    
    if [[ "$public_ip" == "None" || -z "$public_ip" ]]; then
        echo "❌ No public IP found for $env_name"
        return 1
    fi
    
    echo "✅ $env_name: http://$public_ip"
    
    # Test if app is responding with timeout and proper error handling
    if curl -s --max-time 5 --connect-timeout 3 "http://$public_ip" >/dev/null 2>&1; then
        echo "   🟢 Application is responding"
    else
        echo "   🟡 Application may still be starting up or not responding"
    fi
    
    return 0
}

check_environment() {
    local env_dir=$1
    local env_name=$2
    
    if [[ ! -d "$env_dir" ]]; then
        echo "ℹ️ $env_name environment directory not found: $env_dir"
        return 1
    fi
    
    pushd "$env_dir" >/dev/null 2>&1
    
    if [[ ! -f "terraform.tfstate" ]]; then
        echo "ℹ️ No Terraform state found for $env_name"
        popd >/dev/null 2>&1
        return 1
    fi
    
    local cluster_name service_name
    cluster_name=$(terraform output -raw cluster_name 2>/dev/null || true)
    service_name=$(terraform output -raw service_name 2>/dev/null || true)
    
    popd >/dev/null 2>&1
    
    if [[ -z "$cluster_name" || -z "$service_name" ]]; then
        echo "❌ Could not retrieve cluster or service name for $env_name"
        return 1
    fi
    
    get_task_ip "$cluster_name" "$service_name" "$env_name"
}

# Check development environment
check_environment "environments/dev" "Development"

echo ""

# Check production environment  
check_environment "environments/prod" "Production"

# Check staging environment if it exists
if [[ -d "environments/staging" ]]; then
    echo ""
    check_environment "environments/staging" "Staging"
fi

echo ""
echo "💡 Tip: If applications aren't responding, wait 2-3 minutes for containers to start"
echo "📋 Note: Ensure you have proper AWS credentials configured and required permissions"

# Exit successfully even if some environments failed
exit 0