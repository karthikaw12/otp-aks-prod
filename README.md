# OTP Application on Azure Kubernetes Service (AKS)

This project deploys a production-ready OTP (One-Time Password) application on Azure Kubernetes Service using Infrastructure as Code (Terraform) and GitOps principles (ArgoCD).

## Architecture Overview

- **Infrastructure**: Azure Kubernetes Service (AKS) provisioned with Terraform
- **GitOps**: ArgoCD for continuous deployment
- **Application Components**:
  - Frontend (React/Web application)
  - Backend (Node.js API)
  - Database (PostgreSQL StatefulSet)
  - Ingress controller for external access
- **Security**: Pod Security Standards, RBAC enabled
- **Scalability**: Horizontal Pod Autoscaler (HPA) configured

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- Azure subscription with appropriate permissions
- [Git](https://git-scm.com/) installed

## Project Structure

```
.
├── main.tf                  # Main Terraform configuration
├── variables.tf             # Terraform variables
├── outputs.tf               # Terraform outputs
├── terraform.tfvars         # Variable values (not committed to Git)
├── argocd/
│   └── application.yaml     # ArgoCD application manifest
└── k8s/
    ├── namespace/
    │   └── namespace.yaml   # otp-prod namespace
    ├── frontend/
    │   ├── deployment.yaml  # Frontend deployment
    │   └── service.yaml     # Frontend service
    ├── backend/
    │   ├── deployment.yaml  # Backend deployment
    │   └── hpa.yaml         # Horizontal Pod Autoscaler
    ├── database/
    │   ├── statefulset.yaml # PostgreSQL StatefulSet
    │   └── service.yaml     # Database service
    ├── config/
    │   ├── configmap.yaml   # Application configuration
    │   └── secret.yaml      # Sensitive data (base64 encoded)
    ├── storage/
    │   └── storageclass.yaml # Azure Disk storage class
    └── ingress/
        └── ingress.yaml     # Ingress rules for external access
```

## Getting Started

### 1. Configure Azure Authentication

```powershell
# Login to Azure
az login

# Set the subscription
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### 2. Update Terraform Variables

Create or update `terraform.tfvars`:

```hcl
subscription_id = "your-subscription-id"
rg_name        = "otp-rg"
location       = "eastus"
aks_name       = "otp-aks"
```

### 3. Deploy Infrastructure

```powershell
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply -auto-approve
```

This will provision:
- Azure Resource Group
- AKS Cluster with 1 node (Standard_DC2as_v5)
- ArgoCD installed via Helm chart with LoadBalancer service

### 4. Access the AKS Cluster

```powershell
# Get AKS credentials
az aks get-credentials --resource-group otp-rg --name otp-aks

# Verify cluster access
kubectl get nodes

# Check ArgoCD pods
kubectl get pods -n argocd
```

### 5. Access ArgoCD

#### Get ArgoCD Server External IP

```powershell
kubectl get svc argocd-server -n argocd
```

Wait for the `EXTERNAL-IP` to be assigned (may take a few minutes).

#### Get ArgoCD Credentials

**Username**: `admin`

**Password** (PowerShell):
```powershell
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | %{ [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**Password** (Bash/Linux):
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

#### Access ArgoCD UI

Open your browser to: `http://<EXTERNAL-IP>` (or `https://` if TLS is configured)

Login with username `admin` and the password from above.

### 6. Deploy Application with ArgoCD

#### Grant ArgoCD Permissions (if needed)

If you encounter "permission denied" errors, grant ArgoCD cluster-admin access:

```powershell
kubectl create clusterrolebinding argocd-admin --clusterrole=cluster-admin --serviceaccount=argocd:argocd-application-controller
```

#### Update ArgoCD Application Manifest

Edit [argocd/application.yaml](argocd/application.yaml) and update the `repoURL` with your Git repository:

```yaml
source:
  repoURL: https://github.com/<YOUR_ORG>/<YOUR_REPO>.git
  targetRevision: main
  path: k8s
```

#### Apply ArgoCD Application

```powershell
kubectl apply -f argocd/application.yaml
```

ArgoCD will automatically:
- Create the `otp-prod` namespace
- Deploy frontend, backend, and database
- Configure ingress and services
- Monitor and sync changes from Git

### 7. Verify Application Deployment

```powershell
# Check namespace
kubectl get namespace otp-prod

# Check all resources in otp-prod namespace
kubectl get all -n otp-prod

# Check frontend pods
kubectl get pods -n otp-prod -l app=frontend

# Check backend pods
kubectl get pods -n otp-prod -l app=backend

# Check database
kubectl get statefulset -n otp-prod
```

### 8. Access the Application

### Via LoadBalancer Service (Recommended)

The frontend is exposed as a LoadBalancer service. Get the external IP:

```powershell
kubectl get svc frontend -n otp-prod
```

You'll see output like:
```
NAME       TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)
frontend   LoadBalancer   10.0.62.82    4.157.179.40   80:30246/TCP,443:32648/TCP
```

Access your application at:
- HTTP: `http://<EXTERNAL-IP>`
- HTTPS: `https://<EXTERNAL-IP>`

Example: `http://4.157.179.40`

### Via Custom Domain with Ingress

If you configure DNS and want to use your domain (e.g., `skorganics.online`):

1. Point your domain DNS to the LoadBalancer external IP
2. Configure HTTPS via cert-manager (Let's Encrypt)
3. Update the ingress rules

### Backend API

The backend service (`otp-backend`) is accessible within the cluster at:
```
http://otp-backend:4000
```

Test the backend:
```powershell
kubectl port-forward -n otp-prod svc/otp-backend 4000:4000
```

Then access: `http://localhost:4000`

## Application Configuration

### Environment Variables

Update [k8s/config/configmap.yaml](k8s/config/configmap.yaml) for non-sensitive configuration.

Update [k8s/config/secret.yaml](k8s/config/secret.yaml) for sensitive data (remember to base64 encode values).

### Scaling

The backend is configured with HPA in [k8s/backend/hpa.yaml](k8s/backend/hpa.yaml):
- Minimum replicas: 2
- Maximum replicas: 10
- Target CPU utilization: 70%

To manually scale:

```powershell
kubectl scale deployment backend -n otp-prod --replicas=5
```

### Database Persistence

PostgreSQL uses Azure Disk for persistent storage via the StorageClass defined in [k8s/storage/storageclass.yaml](k8s/storage/storageclass.yaml).

## Monitoring and Troubleshooting

### Check Pod Logs

```powershell
# Frontend logs
kubectl logs -f deployment/frontend -n otp-prod

# Backend logs
kubectl logs -f deployment/backend -n otp-prod

# Database logs
kubectl logs -f statefulset/postgres -n otp-prod
```

### Check Pod Status

```powershell
kubectl describe pod <pod-name> -n otp-prod
```

### Check ArgoCD Application Status

```powershell
kubectl get application -n argocd
```

Or view in ArgoCD UI for visual representation of sync status.

### Common Issues

**Permission Denied When Creating ArgoCD Application**
```powershell
# Grant ArgoCD cluster-admin permissions
kubectl create clusterrolebinding argocd-admin --clusterrole=cluster-admin --serviceaccount=argocd:argocd-application-controller

# Verify RBAC permissions
kubectl auth can-i create applications --as=system:serviceaccount:argocd:argocd-application-controller -n argocd
```

**Pods in Pending State**
- Check node resources: `kubectl describe nodes`
- Check PVC binding: `kubectl get pvc -n otp-prod`

**ImagePullBackOff**
- Verify image names in deployment manifests
- Check Docker registry access

**ArgoCD Not Syncing**
- Verify Git repository URL in application.yaml
- Check ArgoCD has access to the repository
- Review ArgoCD application logs: `kubectl logs -n argocd deployment/argocd-application-controller`

## Clean Up

To destroy all resources:

```powershell
# Delete ArgoCD application (will remove all K8s resources)
kubectl delete -f argocd/application.yaml

# Destroy infrastructure
terraform destroy -auto-approve
```

## Security Best Practices

- Store `terraform.tfvars` locally - **never commit to Git**
- Rotate ArgoCD admin password after first login
- Use Azure Key Vault for sensitive secrets (future enhancement)
- Enable pod security policies/standards
- Regularly update container images for security patches
- Use private container registry for production

## GitOps Workflow

1. Make changes to Kubernetes manifests in the `k8s/` directory
2. Commit and push to your Git repository
3. ArgoCD automatically detects changes and syncs to the cluster
4. Monitor deployment status in ArgoCD UI

For manual sync:
```powershell
kubectl patch application otp-prod -n argocd -p '{"operation": {"sync": {}}}' --type merge
```

## Additional Resources

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Support

For issues or questions, please open an issue in the repository.

## License

[Specify your license here]
