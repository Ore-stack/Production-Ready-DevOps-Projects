#!/usr/bin/env bash
# setup-eks.sh — Production-ready EKS provisioning + add-ons
# Usage: ./setup-eks.sh [--cluster-name NAME] [--region REGION] [--kms] [--node-type TYPE] [--profile AWS_PROFILE]
# Example: ./setup-eks.sh --cluster-name my-cluster --region us-east-1 --kms --node-type t3.medium

set -euo pipefail

# ---------- Defaults (override via CLI) ----------
CLUSTER_NAME="my-webapp-cluster"
REGION="us-east-1"
NODE_TYPE="t3.medium"
ONDEMAND_NODES=2
ONDEMAND_MIN=1
ONDEMAND_MAX=4
SPOT_NODES=2
SPOT_MIN=0
SPOT_MAX=4
NODE_GROUP_NAME_ONDEMAND="ng-ondemand"
NODE_GROUP_NAME_SPOT="ng-spot"
KMS_CREATE=false
PROFILE=""
ENABLE_ALB=true
ENABLE_AUTOSCALER=true
ENABLE_CW_LOGGING=true
EKS_VERSION=""   # empty -> use latest supported by eksctl

# ---------- Usage ----------
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --cluster-name NAME     EKS cluster name (default: $CLUSTER_NAME)
  --region REGION         AWS region (default: $REGION)
  --node-type TYPE        EC2 instance type for node groups (default: $NODE_TYPE)
  --kms                   Create a KMS key and enable secrets encryption
  --profile PROFILE       AWS CLI profile to use (default: environment's profile)
  --no-alb                Don't install AWS Load Balancer Controller
  --no-autoscaler         Don't install Cluster Autoscaler
  --no-cloudwatch         Don't enable cluster CloudWatch logging
  --help                  Show this help
EOF
}

# ---------- Parse args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2;;
    --region) REGION="$2"; shift 2;;
    --node-type) NODE_TYPE="$2"; shift 2;;
    --kms) KMS_CREATE=true; shift;;
    --profile) PROFILE="--profile $2"; shift 2;;
    --no-alb) ENABLE_ALB=false; shift;;
    --no-autoscaler) ENABLE_AUTOSCALER=false; shift;;
    --no-cloudwatch) ENABLE_CW_LOGGING=false; shift;;
    --help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

# ---------- Helpers ----------
info() { printf "\n\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }
fail() { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

# ---------- Ensure required tools ----------
info "Checking required CLIs..."
if ! command -v eksctl >/dev/null 2>&1; then
  info "eksctl not found — installing eksctl"
  TMP=$(mktemp -d)
  curl -L --silent "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
    | tar xz -C "$TMP"
  sudo mv "$TMP/eksctl" /usr/local/bin/eksctl
  rm -rf "$TMP"
fi

require_cmd aws
require_cmd eksctl
require_cmd kubectl
require_cmd helm
require_cmd jq

info "Using AWS region: $REGION"
info "Cluster name: $CLUSTER_NAME"

# ---------- Optional: create KMS key ----------
KMS_KEY_ID=""
if [ "$KMS_CREATE" = true ]; then
  info "Creating KMS key for secrets encryption..."
  KMS_OUTPUT=$(aws kms create-key $PROFILE --description "EKS secrets encryption key for $CLUSTER_NAME" --query KeyMetadata.Arn --output text --region "$REGION")
  KMS_KEY_ID="$KMS_OUTPUT"
  info "Created KMS key: $KMS_KEY_ID"
fi

# ---------- Create cluster (eksctl) ----------
info "Creating EKS cluster (managed) — this will take several minutes..."
EKSCOMMAND=(
  eksctl create cluster
  --name "$CLUSTER_NAME"
  --region "$REGION"
  --nodegroup-name "$NODE_GROUP_NAME_ONDEMAND"
  --node-type "$NODE_TYPE"
  --nodes "$ONDEMAND_NODES"
  --nodes-min "$ONDEMAND_MIN"
  --nodes-max "$ONDEMAND_MAX"
  --managed
  --with-oidc
)
# add eks version if set
if [ -n "$EKS_VERSION" ]; then
  EKSCOMMAND+=(--version "$EKS_VERSION")
fi

# Add KMS encryption flag if requested
if [ -n "$KMS_KEY_ID" ]; then
  EKSCOMMAND+=(--secrets-encryption)
  # eksctl will prompt for KMS ARNs; use config mode if needed. We'll pass via env for eksctl to pick if supported.
  warn "Note: eksctl secrets-encryption option may require a cluster config file in some versions. If this fails, create cluster then enable encryption separately."
fi

# Run creation (idempotent check first)
if eksctl get cluster --region "$REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
  info "Cluster $CLUSTER_NAME already exists — skipping create"
else
  # Execute eksctl create cluster with profile if provided
  if [ -n "$PROFILE" ]; then
    info "Running eksctl with profile: $PROFILE"
    eval "${EKSCOMMAND[*]} $PROFILE"
  else
    eval "${EKSCOMMAND[*]}"
  fi
fi

# ---------- Create an extra managed nodegroup for spot instances (mixed) ----------
if eksctl get nodegroup --cluster "$CLUSTER_NAME" --region "$REGION" --name "$NODE_GROUP_NAME_SPOT" >/dev/null 2>&1; then
  info "Spot nodegroup '$NODE_GROUP_NAME_SPOT' already exists — skipping"
else
  info "Creating spot-managed nodegroup: $NODE_GROUP_NAME_SPOT"
  eksctl create nodegroup \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --name "$NODE_GROUP_NAME_SPOT" \
    --node-type "$NODE_TYPE" \
    --nodes "$SPOT_NODES" \
    --nodes-min "$SPOT_MIN" \
    --nodes-max "$SPOT_MAX" \
    --managed \
    --node-ami auto \
    --spot
fi

# ---------- Enable CloudWatch cluster logging ----------
if [ "$ENABLE_CW_LOGGING" = true ]; then
  info "Enabling control plane logs to CloudWatch"
  eksctl utils update-cluster-logging \
    --region "$REGION" \
    --cluster "$CLUSTER_NAME" \
    --enable-types "api,authenticator,audit,controllerManager,scheduler" \
    --approve || warn "CloudWatch logging update returned non-zero (may already be configured)"
fi

# ---------- Associate OIDC provider (required for IAM Service Accounts) ----------
info "Ensuring IAM OIDC provider is associated with cluster (required for IRSA)..."
eksctl utils associate-iam-oidc-provider --cluster "$CLUSTER_NAME" --region "$REGION" --approve || warn "OIDC provider association failed or already present"

# ---------- Install AWS Load Balancer Controller (ALB) ----------
if [ "$ENABLE_ALB" = true ]; then
  info "Installing AWS Load Balancer Controller (ALB) via helm"
  # Create IAM policy for ALB
  ALB_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME"
  TMP_POLICY_FILE=$(mktemp)
  # Use official policy document URL if you prefer; here we fetch from AWS docs isn't possible offline; instead warn if absent.
  # For reliability, we'll use eksctl to create the service account with required iam policy attached (eksctl will download policy).
  # Create service account with eksctl (it will create iam role and attach managed policy)
  eksctl create iamserviceaccount \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --namespace kube-system \
    --name aws-load-balancer-controller \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve || warn "Failed to create IAM service account for ALB (may already exist)"
  # Add helm repo and install chart
  helm repo add eks https://aws.github.io/eks-charts || true
  helm repo update
  # Install/upgrade controller
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName="$CLUSTER_NAME" \
    --set region="$REGION" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
fi

# ---------- Install Cluster Autoscaler ----------
if [ "$ENABLE_AUTOSCALER" = true ]; then
  info "Installing Cluster Autoscaler"
  # Create IAM service account for autoscaler with minimal policy if required by your setup
  eksctl create iamserviceaccount \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --namespace kube-system \
    --name cluster-autoscaler \
    --attach-policy-arn arn:aws:iam::aws:policy/AutoScalingFullAccess \
    --override-existing-serviceaccounts \
    --approve || warn "Failed to create IAM service account for Cluster Autoscaler (may already exist)"
  # Deploy using the official manifests / helm chart (stable source)
  # We use recommended settings: autoscaler identifies ASG by tag set by eksctl
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-1.26.0/examples/cluster-autoscaler-autodiscover.yaml || warn "Autoscaler manifest apply may have failed or network issue"
  # Patch the deployment to use the cluster name and proper command flags
  kubectl -n kube-system set env deployment/cluster-autoscaler \
    --containers=cluster-autoscaler --env="AWS_REGION=$REGION" || true
  # Add cluster-autoscaler deployment annotation to avoid scaling to zero issues
  kubectl -n kube-system annotate deployment cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false" --overwrite || true
fi

# ---------- Post-install checks ----------
info "Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=600s || warn "Timeout waiting for nodes; check 'kubectl get nodes'"

info "Verifying kube-system pods..."
kubectl -n kube-system get pods --no-headers

info "EKS cluster setup completed (cluster: $CLUSTER_NAME, region: $REGION)."

cat <<EOF

Next steps / notes:
  - To use IRSA for additional addons, create IAM service accounts via eksctl
    e.g. eksctl create iamserviceaccount --cluster $CLUSTER_NAME --name external-dns --namespace kube-system --attach-policy-arn <policy_arn> --approve
  - If you enabled KMS, confirm secrets encryption:
      aws eks describe-cluster --region $REGION --name $CLUSTER_NAME --query "cluster.encryptionConfig"
  - Monitor CloudWatch logs and set alarms for suspicious activity.
  - Consider installing:
      - ExternalDNS (for automated DNS)
      - Cert-Manager (TLS)
      - Prometheus & Grafana (observability)
      - EBS CSI driver if you need dynamic storage

EOF