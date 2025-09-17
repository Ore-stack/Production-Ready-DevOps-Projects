
# Project 3: Kubernetes Container Orchestration

Learn to deploy and manage your web application on Kubernetes for enterprise-grade scalability, reliability, and security.

## Project Overview

This project transforms your application into a production-ready Kubernetes deployment with:

- **High Availability**: Multiple container replicas with automatic failover
- **Auto-scaling**: Horizontal scaling based on demand
- **Security**: RBAC, network policies, and security contexts
- **Monitoring**: Integrated health checks and metrics
- **Service Discovery**: Automatic load balancing across pods
- **Zero-downtime Deployments**: Rolling updates and self-healing
- **GitOps Integration**: Automated deployment synchronization
- **Helm Management**: Chart-based application packaging

## Key Features

- **Multi-container orchestration** with pod management
- **Automatic restart** of failed containers
- **Multi-cluster deployment** capabilities
- **Kubernetes security** with Pod Security Admission
- **Network policies** for security segmentation
- **YAML validation** with yamllint pre-application
- **GitOps workflow** with ArgoCD/Flux synchronization
- **Helm chart packaging** for templated deployments
- **Load balancing** across container instances
- **Dynamic scaling** based on resource utilization
- **Kubernetes namespaces** for environment isolation
- **Ingress controllers** for external routing
- **RBAC and network policies** for security
- **Policy enforcement** with Gatekeeper
- **Runtime security** with Falco kernel scanning
- **Cluster Autoscaler** for node management
- **Load balancer integration** for external access
- **Monitoring stack** with Prometheus/Grafana
- **TLS certificates** with cert-manager
- **Service Meshes** (Istio, Linkerd) for advanced traffic management
- **TLS termination** with Let's Encrypt integration

## Deployment Options

### Option A: Local Kubernetes (Recommended for Learning)
- Uses Docker Desktop or Minikube
- Free and quick setup
- Ideal for learning Kubernetes fundamentals

### Option B: AWS EKS (Optional Production Experience)
- Managed Kubernetes service on AWS
- Production-grade environment
- Incurs cloud costs but provides real-world experience

## Prerequisites

### For Local Kubernetes:
- [Docker Desktop](https://www.docker.com/products/docker-desktop) with Kubernetes enabled
- OR [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [yamllint](https://yamllint.readthedocs.io/) for YAML validation
- [Helm](https://helm.sh/docs/intro/install/) for chart management

### For AWS EKS (Optional):
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [eksctl](https://eksctl.io/introduction/#installation)
- Active AWS account (may incur costs)
- [ArgoCD](https://argo-cd.readthedocs.io/) or [Flux](https://fluxcd.io/) for GitOps

## Quick Start

### Step 1: Copy Application Files
```bash
cp ../project-2-cicd-pipeline/app.js .
cp ../project-2-cicd-pipeline/package.json .
cp ../project-2-cicd-pipeline/Dockerfile .
```

### Step 2: Validate Kubernetes Manifests
```bash
# Validate YAML syntax before deployment
yamllint infra/k8s/
yamllint helm/templates/
```

### Step 3: Local Kubernetes Setup

#### Enable Kubernetes in Docker Desktop:
1. Open Docker Desktop → Settings → Kubernetes
2. Check "Enable Kubernetes"
3. Click "Apply & Restart"
4. Wait for "Kubernetes is running" status

#### OR Set Up Minikube:
```bash
minikube start
minikube addons enable metrics-server
eval $(minikube docker-env)  # Configure Docker environment
```

### Step 4: Build and Deploy
```bash
# Build Docker image
docker build -t my-webapp:latest .

# Option 1: Direct kubectl deployment
kubectl apply -f infra/k8s/webapp-deployment.yaml

# Option 2: Helm deployment (recommended)
helm install my-webapp ./helm/

# Verify deployment
kubectl get pods
kubectl get services
kubectl get helmreleases  # If using Flux
```

### Step 5: Access Your Application
```bash
# For Docker Desktop
kubectl get services my-webapp-service

# For Minikube
minikube service my-webapp-service --url
```

## Common Configuration Errors & Solutions

### 1. Label Mismatch Errors
**Error:** `selector does not match template labels`
```yaml
# Incorrect - selector doesn't match template
selector:
  matchLabels:
    app: my-webapp
    version: v1  # This label doesn't exist in template

# Correct - ensure selector matches template labels
selector:
  matchLabels:
    app: my-webapp  # Matches template metadata.labels.app
```

### 2. Service-Pod Connectivity Issues
**Error:** `Endpoints not found for service`
```bash
# Check label selectors match
kubectl get pods --show-labels
kubectl describe service my-webapp-service

# Common fix: Ensure service selector matches pod labels
kubectl label pods <pod-name> app=my-webapp --overwrite
```

### 3. Resource Quota Exceeded
**Error:** `pods failed to fit in any node`
```bash
# Check resource quotas
kubectl describe resourcequota

# Adjust resource requests or increase quotas
kubectl patch deployment my-webapp -p '{"spec":{"template":{"spec":{"containers":[{"name":"webapp","resources":{"requests":{"cpu":"50m","memory":"64Mi"}}}]}}}}'
```

### 4. Image Pull Errors
**Error:** `ImagePullBackOff` or `ErrImagePull`
```bash
# Check image name and tags
kubectl describe pod <pod-name>

# For private registries, ensure imagePullSecrets are configured
kubectl create secret docker-registry regcred \
  --docker-server=<your-registry> \
  --docker-username=<username> \
  --docker-password=<password>
```

### 5. Readiness/Liveness Probe Failures
**Error:** `Readiness probe failed` or `Liveness probe failed`
```bash
# Check application health endpoint
kubectl exec <pod-name> -- curl http://localhost:3001/health

# Adjust probe timing if application starts slowly
kubectl patch deployment my-webapp -p '{"spec":{"template":{"spec":{"containers":[{"name":"webapp","livenessProbe":{"initialDelaySeconds":45}}]}}}}'
```

## GitOps Setup with ArgoCD

### 1. Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Configure Application
```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-webapp
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-prod
  source:
    path: infra/k8s/
    repoURL: https://github.com/your-username/your-repo.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

### 3. Apply GitOps Configuration
```bash
kubectl apply -f argocd-app.yaml
```

## Helm Chart Structure
```
helm/
├── Chart.yaml
├── values.yaml
├── values-prod.yaml
├── values-dev.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    └── hpa.yaml
```

### Deploy with Environment-specific Values
```bash
# Development
helm install my-webapp ./helm/ -f helm/values-dev.yaml

# Production
helm install my-webapp ./helm/ -f helm/values-prod.yaml

# Upgrade deployment
helm upgrade my-webapp ./helm/ -f helm/values-prod.yaml
```

## Kubernetes Features Testing

### Test Scaling:
```bash
kubectl scale deployment my-webapp --replicas=5
kubectl get pods -w  # Watch scaling in action
kubectl scale deployment my-webapp --replicas=2
```

### Test Self-Healing:
```bash
kubectl delete pod [POD-NAME]
kubectl get pods -w  # Watch automatic restart
```

### Test Rolling Updates:
```bash
kubectl set image deployment/my-webapp webapp=my-webapp:v2
kubectl rollout status deployment/my-webapp

# Rollback if needed
kubectl rollout undo deployment/my-webapp
```

## AWS EKS Setup (Optional)

### 1. Create EKS Cluster
```bash
chmod +x eks-setup.sh
./eks-setup.sh
```

### 2. Push Image to ECR
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login \
    --username AWS \
    --password-stdin [ACCOUNT-ID].dkr.ecr.us-east-1.amazonaws.com

# Tag and push image
docker tag my-webapp:latest [ACCOUNT-ID].dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest
docker push [ACCOUNT-ID].dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest
```

### 3. Deploy to EKS with GitOps
```bash
# Update image reference in values.yaml, then let GitOps sync
git add helm/values.yaml
git commit -m "Update image for EKS deployment"
git push origin main
```

## Essential Kubernetes Commands

```bash
# Cluster information
kubectl cluster-info
kubectl get all --all-namespaces
kubectl config current-context

# Debugging and inspection
kubectl describe pod [POD-NAME]
kubectl logs [POD-NAME] -f  # Follow logs
kubectl exec -it [POD-NAME] -- /bin/sh
kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces

# GitOps status
argocd app list
argocd app get my-webapp
flux get sources git
flux get kustomizations

# Helm management
helm list --all-namespaces
helm history my-webapp
helm status my-webapp

# Network troubleshooting
kubectl port-forward service/my-webapp-service 8080:80
kubectl run curl-test --image=radial/busyboxplus:curl -i --tty --rm

# Cleanup
kubectl delete -f infra/k8s/
helm uninstall my-webapp
```

## Troubleshooting Guide

### Common Local Issues:

**"No resources found"**
```bash
kubectl cluster-info
minikube status
kubectl get nodes
```

**"ImagePullBackOff"**
```bash
eval $(minikube docker-env)
docker build -t my-webapp:latest .
docker images | grep my-webapp
```

**"Pods stuck in Pending"**
```bash
kubectl describe nodes
kubectl get events --field-selector=type=Warning
kubectl describe pod <pod-name>
```

### Application Issues:

**"Can't access the app"**
```bash
kubectl get services -o wide
kubectl get endpoints my-webapp-service
kubectl get pods --selector=app=my-webapp
kubectl logs [POD-NAME]
```

**"Health checks failing"**
```bash
kubectl exec [POD-NAME] -- curl -v http://localhost:3001/health
kubectl port-forward [POD-NAME] 3001:3001
curl -v http://localhost:3001/health
```

### GitOps/Helm Issues:

**"Helm release failed"**
```bash
helm status my-webapp
helm get manifest my-webapp | kubectl get -f -
kubectl get events --field-selector=involvedObject.name=my-webapp
```

**"ArgoCD sync failed"**
```bash
argocd app sync my-webapp
argocd app history my-webapp
kubectl get applications -n argocd
```

## Cleanup Procedures

### Local Environment:
```bash
# Cleanup deployment
kubectl delete -f infra/k8s/
helm uninstall my-webapp

# Full cleanup
minikube stop
minikube delete
docker system prune -a
```

### AWS EKS:
```bash
# Cleanup application
kubectl delete -f infra/k8s/
helm uninstall my-webapp

# Delete cluster
eksctl delete cluster --name my-webapp-cluster --region us-east-1

# Cleanup ECR resources
aws ecr delete-repository --repository-name my-webapp --force
```

## Skills Acquired

✅ Kubernetes architecture and components  
✅ Pod deployment and management with GitOps  
✅ Service discovery and load balancing  
✅ Configuration management with ConfigMaps and Helm  
✅ Health monitoring with probes  
✅ Rolling updates and zero-downtime deployments  
✅ Horizontal pod autoscaling  
✅ Production deployment strategies with EKS  
✅ GitOps workflows with ArgoCD/Flux  
✅ Helm chart development and management  
✅ Multi-environment configuration management  
✅ YAML validation and best practices  

## Real-World Applications

- Microservices architecture implementation
- High-availability production systems with GitOps
- Traffic-driven automatic scaling
- Enterprise-grade resilient infrastructure
- Cloud-native application deployment
- Infrastructure as Code (IaC) with Helm
- Continuous Deployment with GitOps
- Multi-cluster management strategies

## Next Steps & Advanced Topics

1. **Implement Custom Resource Definitions (CRDs)** for extended functionality
2. **Set up Kubernetes Operators** for application-specific controllers
3. **Explore Service Meshes** (Istio, Linkerd) for advanced traffic management
4. **Implement multi-cluster GitOps** with ArgoCD ApplicationSet
5. **Configure centralized logging** with Loki and Grafana
6. **Set up distributed tracing** with Tempo or Jaeger
7. **Implement policy enforcement** with OPA/Gatekeeper
8. **Configure node affinity/taints** for workload placement
9. **Set up backup/restore** procedures with Velero
10. **Implement multi-cluster management** with Cluster API
11. **Explore Kubernetes security** with Pod Security Admission
12. **Set up custom metrics** for HPA with Prometheus adapter
13. **Implement resource quotas** and limit ranges
14. **Explore stateful applications** with StatefulSets and persistent storage
15. **Set up Kubernetes dashboard** and monitoring tools
16. **Implement network policies** for security segmentation
17. **Configure certificate management** with cert-manager
18. **Set up storage classes** and persistent volume claims
19. **Implement canary deployments** with Flagger and Istio
20. **Set up cost optimization** with Kubecost or OpenCost
21. **Implement chaos engineering** with LitmusChaos or Chaos Mesh
22. **Configure multi-tenancy** with virtual clusters or namespaces
23. **Set up GPU acceleration** for machine learning workloads
24. **Implement service discovery** with ExternalDNS and CoreDNS
25. **Configure auto-remediation** with Robusta or Kube-bench

## Project 4 Preparation

Move on to Project 4: Monitoring and Observability where you'll learn to:
- Implement comprehensive monitoring with Prometheus
- Create dashboards with Grafana
- Set up alerting with Alertmanager
- Implement distributed tracing with Jaeger
- Establish logging pipelines with Loki
- Monitor application performance metrics
- Implement event-driven architectures with Knative
- Set up GitOps-driven database management for disaster recovery
- Configure synthetic monitoring and uptime checks
- Implement custom metrics for business KPIs
- Set up anomaly detection with Prometheus recording rules
- Implement log-based alerting and correlation
- Configure multi-cluster monitoring solutions
- Set up user behavior analytics and performance monitoring

---

🎉 **Congratulations! You've successfully deployed a production-ready application on Kubernetes with GitOps and Helm!**
