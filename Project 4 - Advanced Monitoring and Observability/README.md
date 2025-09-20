# Project 4 - Advanced Monitoring and Observability

## Project Overview

This project demonstrates deploying **Grafana** on an **AWS EKS Kubernetes cluster** with persistent storage, custom node affinity, and Helm-based deployment.
It covers real-world challenges such as PV topology conflicts, resource constraints, and Helm upgrade issues.

---

## Architecture

**High-Level Components:**

- **EKS Cluster**: Multi-node, multi-AZ cluster.
- **Worker Nodes**: On-Demand and Spot EC2 instances.
- **Storage**: EBS volumes with CSI driver.
- **Grafana**: Stateful monitoring pod deployed via Helm.
- **Node Affinity**: Ensures pods schedule in the same AZ as PVs.

**Architecture Diagram (ASCII-style for Markdown):**

       +------------------------+
       |        User            |
       +-----------+------------+
                   |
                   v
       +------------------------+
       |   kubectl / Helm       |
       +-----------+------------+
                   |
                   v
       +------------------------+
       |      EKS Cluster       |
       |                        |
       |  +------------------+  |
       |  |  NodeGroup 1      |  |
       |  |  AZ: us-east-1d   |  |
       |  +------------------+  |
       |                        |
       |  +------------------+  |
       |  |  NodeGroup 2      |  |
       |  |  AZ: us-east-1b   |  |
       |  +------------------+  |
       +------------------------+
                   |
                   v
       +------------------------+
       | PersistentVolumeClaims |
       | (EBS gp2-immediate-new)|
       +------------------------+
                   |
                   v
             +------------+
             | Grafana Pod |
             +------------+

---

## Prerequisites

- AWS account with EKS permissions.
- `kubectl`, `helm` (v3+), and `eksctl` installed.
- AWS CLI configured.
- Kubernetes cluster context.
- Base OS with Docker and Kubernetes support.

---

## Step-by-Step Setup

### 1. Apply StorageClass
```bash
kubectl apply -f gp2-immediate-sc.yaml

2. Deploy Grafana via Helm

helm upgrade --install grafana grafana/grafana -n monitoring -f values-grafana.yaml

3. Verify PVCs

kubectl get pvc -n monitoring
kubectl get pv

4. Check Pod Status

kubectl get pods -n monitoring
kubectl describe pod <grafana-pod-name> -n monitoring

5. Port-forward to Grafana

export POD_NAME=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl -n monitoring port-forward $POD_NAME 3000



⸻

Common Errors & Solutions

Error    Cause    Solution
PVC spec immutable    StorageClass change for existing PVC    Delete the PVC and rerun Helm
Pod Pending: unbound PVC    PV not yet bound    Delete existing PVC or ensure correct StorageClass
Node affinity conflict    Node labels do not match pod affinity    Update values-grafana.yaml with correct nodeAffinity
Insufficient memory / Too many pods    Node resource limits reached    Scale nodegroup or adjust pod requests/limits
StorageClass updates forbidden    Attempt to modify an existing StorageClass    Create a new StorageClass with a new name



⸻

Best Practices
    •    Dynamic provisioning using CSI drivers.
    •    Node affinity to satisfy PV topology constraints.
    •    Set proper resource requests/limits.
    •    Use Helm for repeatable deployments.
    •    Secrets for sensitive data.
    •    Pod security context for FS and privilege restrictions.

⸻

Production Considerations
    •    Enable Grafana HA with multiple replicas.
    •    Monitor node resource usage.
    •    Multi-AZ deployments for reliability.
    •    Backup persistent storage.
    •    Automate deployment with CI/CD.

⸻

Cleanup

helm uninstall grafana -n monitoring
kubectl delete pvc -n monitoring grafana
kubectl delete sc gp2-immediate-new



⸻

Lessons Learned
    •    Node affinity must align with PV AZ for scheduling.
    •    PVCs are immutable; StorageClass changes require PVC recreation.
    •    Scaling nodes may be required to satisfy resource requests.
    •    Helm simplifies deployments but requires careful PV handling.

⸻

Real-World Applications
    •    Observability stack deployment in Kubernetes.
    •    Stateful applications requiring persistent storage.
    •    Multi-AZ resource scheduling and monitoring.
    •    CI/CD deployment automation for monitoring apps.

⸻

Next Steps
    •    Integrate Prometheus and Alertmanager.
    •    Automate Grafana dashboard provisioning.
    •    Enable Ingress/TLS for secure access.
    •    Explore multi-cluster Grafana deployment.
    •    Implement automated scaling and monitoring pipelines.

⸻

References
    •    Grafana Helm Chart
    •    AWS EKS CSI Driver
    •    Kubernetes Persistent Volumes
    •    Helm Upgrade & PVC Handling

