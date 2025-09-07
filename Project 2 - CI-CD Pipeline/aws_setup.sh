#!/bin/bash
# AWS Infrastructure Setup for CI/CD Pipeline
# Description: This script sets up all necessary AWS resources for a CI/CD pipeline
# that deploys a Node.js web app to ECS Fargate using GitHub Actions.

set -e  # Exit on any error

# Configuration variables (customize these as needed)
CLUSTER_NAME="webapp-cicd-cluster"
SERVICE_NAME="webapp-cicd-service"
TASK_FAMILY="webapp-cicd-task"
ECR_REPOSITORY="my-webapp"
AWS_REGION="us-east-1"
GITHUB_USER_NAME="github-actions-user"
CONTAINER_PORT="3001"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Setting up AWS infrastructure for CI/CD${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "Cluster: ${GREEN}$CLUSTER_NAME${NC}"
echo -e "Service: ${GREEN}$SERVICE_NAME${NC}"
echo -e "ECR Repository: ${GREEN}$ECR_REPOSITORY${NC}"
echo -e "Region: ${GREEN}$AWS_REGION${NC}"
echo -e "Container Port: ${GREEN}$CONTAINER_PORT${NC}"
echo ""

# Check if AWS CLI is configured
echo -e "${BLUE}Checking AWS CLI configuration...${NC}"
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}❌ AWS CLI not configured. Please run 'aws configure' first.${NC}"
    echo -e "Steps:"
    echo -e "1. Visit https://console.aws.amazon.com/iam/ to create an IAM user"
    echo -e "2. Attach AdministratorAccess policy (for learning purposes)"
    echo -e "3. Create access keys for the user"
    echo -e "4. Run: ${YELLOW}aws configure${NC}"
    echo -e "5. Enter your Access Key, Secret Key, region ($AWS_REGION), and output format (json)"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI configured${NC}"

# Check if jq is installed (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️ jq not found. Installing jq...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y jq
    else
        echo -e "${RED}❌ jq is required. Please install jq manually.${NC}"
        exit 1
    fi
fi

# 1. Create ECR Repository
echo -e "${BLUE}📦 Creating ECR repository...${NC}"
if aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ECR repository already exists${NC}"
else
    aws ecr create-repository \
        --repository-name $ECR_REPOSITORY \
        --region $AWS_REGION \
        --image-scanning-configuration scanOnPush=true
    echo -e "${GREEN}✅ ECR repository created${NC}"
fi

# Get ECR repository URI
ECR_URI=$(aws ecr describe-repositories \
    --repository-names $ECR_REPOSITORY \
    --region $AWS_REGION \
    --query 'repositories[0].repositoryUri' \
    --output text)

echo -e "${GREEN}✅ ECR URI: $ECR_URI${NC}"

# 2. Create IAM role for ECS task execution
echo -e "${BLUE}🔐 Creating ECS execution role...${NC}"
EXECUTION_ROLE_NAME="ecsTaskExecutionRole-$CLUSTER_NAME"

if aws iam get-role --role-name $EXECUTION_ROLE_NAME >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ECS execution role already exists${NC}"
else
    aws iam create-role \
        --role-name $EXECUTION_ROLE_NAME \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "ecs-tasks.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }'

    aws iam attach-role-policy \
        --role-name $EXECUTION_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
    
    echo -e "${GREEN}✅ ECS execution role created${NC}"
fi

# Get execution role ARN
EXECUTION_ROLE_ARN=$(aws iam get-role \
    --role-name $EXECUTION_ROLE_NAME \
    --query 'Role.Arn' \
    --output text)

# 3. Create ECS cluster
echo -e "${BLUE}🏗️ Creating ECS cluster...${NC}"
if aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ECS cluster already exists${NC}"
else
    aws ecs create-cluster \
        --cluster-name $CLUSTER_NAME \
        --region $AWS_REGION
    echo -e "${GREEN}✅ ECS cluster created${NC}"
fi

# 4. Get VPC and subnet information
echo -e "${BLUE}🌐 Getting VPC information...${NC}"
DEFAULT_VPC=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text)

if [ "$DEFAULT_VPC" = "None" ]; then
    echo -e "${RED}❌ No default VPC found. Please create a VPC or modify this script.${NC}"
    exit 1
fi

SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
    --query 'Subnets[*].SubnetId' \
    --output text | tr '\t' ',')

echo -e "${GREEN}✅ VPC: $DEFAULT_VPC${NC}"
echo -e "${GREEN}✅ Subnets: $SUBNETS${NC}"

# 5. Create security group
echo -e "${BLUE}🛡️ Creating security group...${NC}"
SECURITY_GROUP_NAME="webapp-cicd-sg"

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" "Name=vpc-id,Values=$DEFAULT_VPC" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)

if [ -n "$SECURITY_GROUP_ID" ] && [ "$SECURITY_GROUP_ID" != "None" ]; then
    echo -e "${GREEN}✅ Security group already exists: $SECURITY_GROUP_ID${NC}"
else
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP_NAME \
        --description "Security group for webapp CI/CD" \
        --vpc-id $DEFAULT_VPC \
        --query 'GroupId' \
        --output text)

    # Add inbound rule for the container port
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port $CONTAINER_PORT \
        --cidr 0.0.0.0/0

    echo -e "${GREEN}✅ Security group created: $SECURITY_GROUP_ID${NC}"
fi

# 6. Create CloudWatch log group
echo -e "${BLUE}📊 Creating CloudWatch log group...${NC}"
LOG_GROUP_NAME="/ecs/$TASK_FAMILY"

if aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP_NAME --query 'logGroups[0].logGroupName' --output text >/dev/null 2>&1; then
    echo -e "${GREEN}✅ CloudWatch log group already exists${NC}"
else
    aws logs create-log-group \
        --log-group-name $LOG_GROUP_NAME \
        --region $AWS_REGION
    echo -e "${GREEN}✅ CloudWatch log group created${NC}"
fi

# 7. Create initial task definition with placeholder image
echo -e "${BLUE}📋 Creating initial task definition...${NC}"
aws ecs register-task-definition \
    --family $TASK_FAMILY \
    --network-mode awsvpc \
    --requires-compatibilities FARGATE \
    --cpu 256 \
    --memory 512 \
    --execution-role-arn $EXECUTION_ROLE_ARN \
    --container-definitions '[
        {
            "name": "webapp",
            "image": "nginx:alpine",
            "portMappings": [
                {
                    "containerPort": '$CONTAINER_PORT',
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "ENVIRONMENT",
                    "value": "production"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "'$LOG_GROUP_NAME'",
                    "awslogs-region": "'$AWS_REGION'",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]' \
    --region $AWS_REGION >/dev/null

echo -e "${GREEN}✅ Initial task definition created${NC}"

# 8. Create ECS service
echo -e "${BLUE}�� Creating ECS service...${NC}"
if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ECS service already exists${NC}"
else
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --task-definition $TASK_FAMILY \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --region $AWS_REGION >/dev/null
    echo -e "${GREEN}✅ ECS service created${NC}"
fi

# 9. Create IAM user for GitHub Actions
echo -e "${BLUE}👤 Creating GitHub Actions IAM user...${NC}"
if aws iam get-user --user-name $GITHUB_USER_NAME >/dev/null 2>&1; then
    echo -e "${GREEN}✅ GitHub Actions user already exists${NC}"
    echo -e "${YELLOW}ℹ️ You may need to create new access keys if you don't have them${NC}"
else
    aws iam create-user --user-name $GITHUB_USER_NAME
    
    # Attach policies for GitHub Actions
    aws iam attach-user-policy \
        --user-name $GITHUB_USER_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
    
    aws iam attach-user-policy \
        --user-name $GITHUB_USER_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
    
    echo -e "${GREEN}✅ GitHub Actions user created with ECS and ECR permissions${NC}"
fi

# Create access keys for GitHub Actions
echo -e "${BLUE}🔑 Creating access keys for GitHub Actions...${NC}"
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name $GITHUB_USER_NAME 2>/dev/null || echo "failed")

if [ "$ACCESS_KEY_OUTPUT" = "failed" ]; then
    echo -e "${YELLOW}⚠️ Could not create new access keys (user may already have 2 keys)${NC}"
    echo -e "${YELLOW}ℹ️ You may need to delete old keys first or use existing ones${NC}"
    AWS_ACCESS_KEY_ID="[Use existing or create new access key]"
    AWS_SECRET_ACCESS_KEY="[Use existing or create new secret key]"
else
    AWS_ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
    AWS_SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}🎉 SETUP COMPLETE!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${BLUE}📋 GitHub Repository Secrets to Add:${NC}"
echo ""
echo -e "AWS_ACCESS_KEY_ID: ${YELLOW}$AWS_ACCESS_KEY_ID${NC}"
echo -e "AWS_SECRET_ACCESS_KEY: ${YELLOW}$AWS_SECRET_ACCESS_KEY${NC}"
echo -e "AWS_REGION: ${YELLOW}$AWS_REGION${NC}"
echo -e "ECR_REPOSITORY: ${YELLOW}$ECR_REPOSITORY${NC}"
echo -e "ECR_REGISTRY: ${YELLOW}${ECR_URI%/*}${NC}"  # Remove repository name to get registry
echo -e "ECS_CLUSTER: ${YELLOW}$CLUSTER_NAME${NC}"
echo -e "ECS_SERVICE: ${YELLOW}$SERVICE_NAME${NC}"
echo -e "ECS_TASK_DEFINITION: ${YELLOW}$TASK_FAMILY${NC}"
echo -e "CONTAINER_PORT: ${YELLOW}$CONTAINER_PORT${NC}"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo -e "1. Go to your GitHub repository"
echo -e "2. Navigate to ${YELLOW}Settings → Secrets → Actions${NC}"
echo -e "3. Add each of the above values as repository secrets"
echo -e "4. Create a ${YELLOW}.github/workflows/deploy.yml${NC} file in your project"
echo -e "5. Push your code to trigger the first deployment"
echo -e "6. Watch the GitHub Actions workflow in the Actions tab"
echo -e "7. Get your app URL from the workflow output or AWS Console"
echo ""
echo -e "${BLUE}📝 Sample GitHub Actions workflow:${NC}"
echo -e "Create a file named ${YELLOW}.github/workflows/deploy.yml${NC} with:"
cat << 'EOF'
name: Deploy to ECS

on:
  push:
    branches: [ main ]

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: my-webapp
  ECS_SERVICE: webapp-cicd-service
  ECS_CLUSTER: webapp-cicd-cluster
  ECS_TASK_DEFINITION: webapp-cicd-task
  CONTAINER_NAME: webapp

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    - name: Build, tag, and push image to Amazon ECR
      id: build-image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

    - name: Download task definition
      run: |
        aws ecs describe-task-definition --task-definition $ECS_TASK_DEFINITION \
          --query taskDefinition > task-definition.json

    - name: Fill in the new image ID in the Amazon ECS task definition
      id: task-def
      uses: aws-actions/amazon-ecs-render-task-definition@v1
      with:
        task-definition: task-definition.json
        container-name: $CONTAINER_NAME
        image: ${{ steps.build-image.outputs.image }}

    - name: Deploy Amazon ECS task definition
      uses: aws-actions/amazon-ecs-deploy-task-definition@v1
      with:
        task-definition: ${{ steps.task-def.outputs.task-definition }}
        service: $ECS_SERVICE
        cluster: $ECS_CLUSTER
        wait-for-service-stability: true
EOF
echo ""
echo -e "${RED}🧹 To clean up later:${NC}"
echo -e "Run: ${YELLOW}./cleanup-aws.sh${NC} (create this script to avoid unexpected charges)"
echo ""
echo -e "${GREEN}==========================================${NC}"
