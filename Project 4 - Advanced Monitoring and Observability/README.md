# Project 4: Advanced Monitoring and Observability on AWS EKS

## 📊 Project Overview

This project demonstrates a production-grade monitoring and observability stack deployed on AWS EKS, featuring Grafana with persistent storage, custom node affinity, and Helm-based deployment. The implementation addresses real-world challenges in provisioning, scheduling, and persistent volume management in multi-AZ Kubernetes environments.

![AWS EKS Monitoring Architecture](https://via.placeholder.com/800x400/326ce5/ffffff?text=AWS+EKS+Monitoring+Architecture)

## 🏗️ Architecture

```mermaid
graph TB
    subgraph AWS Cloud
        subgraph VPC
            subgraph Public Subnets
                LB[Application Load Balancer]
                NG[NAT Gateway]
            end
            subgraph Private Subnets
                subgraph EKS Cluster
                    subgraph Node Group - us-east-1a
                        N1[Worker Node 1]
                        N2[Worker Node 2]
                    end
                    subgraph Node Group - us-east-1b
                        N3[Worker Node 3]
                        N4[Worker Node 4]
                    end
                    subgraph Monitoring Namespace
                        G[Grafana Pod]
                        P[Prometheus Pod]
                        A[Alertmanager Pod]
                    end
                end
            end
        end
        subgraph AWS Services
            S3[(S3 Bucket<br/>Dashboard Backups)]
            RDS[(RDS<br/>Grafana Database)]
            ECR[ECR Registry<br/>Container Images]
        end
    end
    User[End User] --> LB
    LB --> N1
    LB --> N3
    N1 --> G
    N3 --> P
    G --> RDS
    G --> S3
    P --> A
    A --> SNS[SNS Notifications]
    classDef aws fill:#ff9900,color:#000;
    classDef k8s fill:#326ce5,color:#fff;
    classDef service fill:#8c5fff,color:#fff;
    class VPC,AWS Services aws;
    class EKS Cluster,Monitoring Namespace k8s;
    class S3,RDS,ECR,SNS service;
```

## 📋 Prerequisites

### Tools Required
```bash
# AWS CLI configuration
aws configure

# EKS cluster access
aws eks update-kubeconfig --region us-east-1 --name my-cluster

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

### AWS Requirements
- AWS account with EKS permissions
- IAM user with appropriate permissions
- EKS cluster running in your desired region
- VPC with public and private subnets

## 🚀 Quick Start Deployment

### 1. Create Monitoring Namespace
```bash
kubectl create namespace monitoring
```

### 2. Deploy Custom StorageClass
```yaml
# gp2-immediate-sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2-immediate-new
provisioner: ebs.csi.aws.com
volumeBindingMode: Immediate
allowVolumeExpansion: true
parameters:
  type: gp2
  encrypted: "true"
```
```bash
kubectl apply -f gp2-immediate-sc.yaml
```

### 3. Deploy Grafana with Helm
```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Grafana with custom values
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  -f values-grafana.yaml
```

### 4. Example values-grafana.yaml
```yaml
# values-grafana.yaml
persistence:
  enabled: true
  storageClassName: gp2-immediate-new
  size: 10Gi
  accessModes:
    - ReadWriteOnce

adminUser: admin
adminPassword: "your-secure-password-here"

service:
  type: LoadBalancer
  port: 80
  targetPort: 3000
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"

resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"

nodeSelector:
  node.kubernetes.io/instance-type: m5.large

tolerations:
- key: "spot"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.kubernetes.io/zone
          operator: In
          values:
          - us-east-1a
```

### 5. Verify Deployment
```bash
# Check pod status
kubectl get pods -n monitoring --watch

# Check persistent volumes
kubectl get pvc -n monitoring
kubectl get pv

# Get Grafana service details
kubectl get svc -n monitoring grafana

# Access Grafana UI
export GRAFANA_LB=$(kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Access Grafana at: http://$GRAFANA_LB"

# Get admin password
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

## 🔧 Advanced Configuration

### AWS IAM Roles for Service Accounts (IRSA)
```bash
# Create IAM OIDC provider
eksctl utils associate-iam-oidc-provider --cluster my-cluster --approve

# Create IAM policy for CloudWatch access
cat > cloudwatch-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:Describe*",
                "cloudwatch:Get*",
                "cloudwatch:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
  --policy-name GrafanaCloudWatchAccess \
  --policy-document file://cloudwatch-policy.json

# Create service account with IAM role
eksctl create iamserviceaccount \
  --name grafana-service-account \
  --namespace monitoring \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::AWS_ACCOUNT_ID:policy/GrafanaCloudWatchAccess \
  --approve
```

### CloudWatch Data Source Configuration
```yaml
# cloudwatch-datasource.yaml
apiVersion: 1
datasources:
  - name: CloudWatch
    type: cloudwatch
    access: proxy
    jsonData:
      authType: default
      defaultRegion: us-east-1
    secureJsonData:
      accessKey: "${AWS_ACCESS_KEY_ID}"
      secretKey: "${AWS_SECRET_ACCESS_KEY}"
```

## 🚨 Alerting and Monitoring

### Prometheus Deployment
```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set alertmanager.persistentVolume.storageClass="gp2" \
  --set server.persistentVolume.storageClass="gp2" \
  --set server.retention="15d" \
  --set server.service.type=LoadBalancer
```

### Example Alert Rules
```yaml
# prometheus-rules.yaml
groups:
- name: example
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on instance {{ $labels.instance }}"
      description: "CPU usage is above 85% for 10 minutes"
  - alert: PodRestartFrequently
    expr: rate(kube_pod_container_status_restarts_total[5m]) * 60 > 5
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Pod {{ $labels.pod }} is restarting frequently"
      description: "Pod {{ $labels.pod }} is restarting more than 5 times per minute"
```

## 🔐 Security Hardening

### Network Policies
```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: monitoring
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

### Pod Security Context
```yaml
# Add to values-grafana.yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  runAsGroup: 1000

grafana:
  securityContext:
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
```

## 📊 Sample Dashboards

### Kubernetes Cluster Dashboard
- **Cluster Health**: Node status, pod count, resource utilization
- **Workload Monitoring**: Deployment status, replica counts
- **Resource Usage**: CPU/Memory requests vs usage
- **Network Metrics**: Traffic volume, error rates

### AWS Resource Dashboard
- **EC2 Metrics**: CPU utilization, disk I/O
- **RDS Monitoring**: Database connections, storage
- **ELB Metrics**: Request counts, latency
- **S3 Metrics**: Bucket size, request rates

## ⚠️ Troubleshooting Common Issues

### 1. StorageClass Update Forbidden
```bash
# Error: StorageClass updates to parameters are forbidden
# Solution: Create a new StorageClass
kubectl delete storageclass gp2-immediate-new
kubectl apply -f gp2-immediate-sc.yaml
```

### 2. Pod Pending - Unbound PVC
```bash
# Error: pod has unbound immediate PersistentVolumeClaims
# Solution: Delete and recreate PVC
kubectl delete pvc -n monitoring grafana
helm upgrade grafana grafana/grafana -n monitoring -f values-grafana.yaml
```

### 3. Node Affinity Conflicts
```bash
# Error: node(s) didn't match Pod's node affinity
# Solution: Scale nodegroup or update affinity rules
eksctl scale nodegroup --cluster my-cluster --name ng-main --nodes 3
```

### 4. Resource Constraints
```bash
# Error: Insufficient memory, too many pods
# Solution: Scale nodegroup or adjust resource requests
eksctl scale nodegroup --cluster my-cluster --name ng-main --nodes 4
```

## 🧹 Cleanup

```bash
# Uninstall Helm releases
helm uninstall grafana -n monitoring
helm uninstall prometheus -n monitoring

# Delete persistent volumes
kubectl delete pvc -n monitoring --all

# Delete namespace
kubectl delete namespace monitoring

# Delete IAM resources
aws iam delete-role-policy --role-name eksctl-my-cluster-role --policy-name GrafanaCloudWatchAccess
```

## 📚 Best Practices

1. **Use Persistent Storage**: Always enable persistence for stateful applications like Grafana
2. **Implement Resource Limits**: Set appropriate requests and limits for all containers
3. **Enable Security Contexts**: Run containers as non-root users with read-only filesystems
4. **Use Node Affinity**: Ensure pods are scheduled in appropriate availability zones
5. **Implement Backup Strategies**: Regularly backup Grafana dashboards and configuration
6. **Monitor Resource Usage**: Set up alerts for resource consumption and performance issues

## 🚀 Next Steps

1. **Integrate Prometheus and Alertmanager** for complete monitoring solution
2. **Set up Grafana dashboards** via ConfigMaps for infrastructure monitoring
3. **Implement TLS/Ingress** for secure external access
4. **Configure AWS CloudWatch integration** for hybrid monitoring
5. **Set up automated backups** for Grafana dashboards and data
6. **Implement CI/CD pipeline** for monitoring stack updates

## 📖 References

- [Grafana Helm Chart Documentation](https://grafana.com/docs/grafana/latest/setup-grafana/installation/kubernetes/)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Storage Documentation](https://kubernetes.io/docs/concepts/storage/)
- [Prometheus Operator Guide](https://prometheus-operator.dev/docs/)
