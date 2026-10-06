# Building an End-to-End DevOps Project on AWS using Terraform, Kubernetes, Jenkins (CI/CD), GitOps, ArgoCD with Full Prometheus Monitoring & Grafana Visualization

In this project, I build a full end-to-end DevOps project on AWS with GitOps workflow. The entire infrastructure was provisioned using Terraform, with state and lock management in AWS S3. The application code is managed on GitHub, and a webhook triggers Jenkins to clone the repo, build a Docker image, push it to Amazon ECR, and update a GitOps-managed repo. ArgoCD watches this repo and automatically deploys to Amazon EKS, using Kubernetes Deployments for app pods and StatefulSets for database pods, backed by Amazon EFS for persistent storage. External access is routed via an Ingress Controller using AWS ALB, secured by AWS Certificate Manager (ACM) and Route 53 for DNS. The entire stack is monitored by Prometheus and visualized through Grafana, with RBAC controlling access and alerts sent via email for any failures in Jenkins pipelines or unhealthy services. 

The tech stack includes Terraform, GitHub, Jenkins, Docker, ArgoCD, Helm, Kubernetes, AWS EKS, ECR, EFS, ALB, ACM, Route 53, Prometheus, Grafana, ConfigMap, Secrets, RBAC, and more — delivering a robust, automated, scalable, and secure DevOps pipeline.

![DevOps](https://github.com/user-attachments/assets/9cdbbd38-930b-4b7e-87f7-dd3e98c25f4a)




## 📘 Full step-by-step guide

**[docs/RUNBOOK.md](docs/RUNBOOK.md)** (also as **[PDF](docs/DevOps-Project-Runbook.pdf)**) walks through every phase with exact commands, expected output and checks: prerequisites, Terraform, EKS add-ons, Jenkins, security scanning, ArgoCD, the CI/CD loop, monitoring (in-cluster and EC2), HTTPS, troubleshooting and teardown.

## 🔁 Pipeline

```
 git push ──▶ GitHub ──webhook──▶ Jenkins (EC2)
                                    │ 1. clone main (skip if "[skip ci]")
                                    │ 2. Django unit tests
                                    │ 3. Trivy: secrets (blocking) + IaC/deps report
                                    │ 4. docker build (non-root, gunicorn)
                                    │ 5. Trivy image scan (blocks on fixable CRITICAL)
                                    │ 6. push to ECR  ─────────────────────────────┐
                                    │ 7. bump image tag in appdeployment.yml        │
                                    ▼ 8. commit "[skip ci]" + push                  │
                                 GitHub                                             │
                                    │ ArgoCD watches "Kubernetes with ArgoCD/"     │
                                    ▼                                               ▼
   Internet ──▶ ALB (AWS LB Controller) ──▶ EKS: app-pod x2 ──▶ mydb (MySQL StatefulSet on EFS)
                                              ▲
             Prometheus / Grafana / Alertmanager (in-cluster + EC2) ──▶ email alerts
```

## 🗂️ Repository layout

| Path | What it contains |
|---|---|
| [`Terraform/`](Terraform) | VPC, EC2 (Jenkins, monitoring), EKS + Pod Identity roles, EFS, ECR, optional Route 53/ACM. S3 backend with native locking |
| [`Jenkins_cicd/`](Jenkins_cicd) | Django CRUD app, `Dockerfile` (multi-stage, non-root), `requirements.txt`, unit tests, **`Jenkinsfile`** |
| [`Kubernetes with ArgoCD/`](Kubernetes%20with%20ArgoCD) | Manifests ArgoCD syncs into `k8s-project`: Deployment, StatefulSet, Services, Ingress (ALB), ConfigMap, Secret, StorageClass (EFS), RBAC |
| [`Install and Configuration/`](Install%20and%20Configuration) | Jenkins server installer, ArgoCD Application, EFS/LB controller Helm commands, Prometheus/Alertmanager/Grafana guides, alert rules, kube-prometheus-stack values |
| [`Security/`](Security) | Trivy config + scan script, NetworkPolicies, kube-bench (CIS EKS) job, security guide |
| [`docs/`](docs) | Runbook (Markdown + PDF) and the script that builds the PDF |

## 🛠️ Tech stack

| Area | Tools |
|---|---|
| Infrastructure as Code | Terraform (S3 state + lockfile) |
| Cloud | AWS VPC, EC2, EKS, ECR, EFS, ALB, IAM (Pod Identity), Route 53, ACM |
| CI | Jenkins, Docker, GitHub webhooks |
| CD / GitOps | ArgoCD (auto-sync, prune, self-heal) |
| DevSecOps | Trivy (secrets, IaC, dependencies, image), ECR scan-on-push, kube-bench, NetworkPolicies, Pod Security Standards |
| Monitoring | Prometheus, Alertmanager (email), Grafana, node_exporter, Pushgateway, kube-prometheus-stack |
| App | Python 3.12, Django 5.2 LTS, gunicorn, MySQL 8 |

## 🚀 Quick start (summary of the runbook)

```bash
# 0. prerequisites: aws configure (ap-south-1), terraform, kubectl, helm
git clone https://github.com/gh-vishwesh/End-to-End-DevOps-Project.git && cd End-to-End-DevOps-Project

# 1. infrastructure
cd Terraform && cp example.tfvars terraform.tfvars   # set admin_cidr to your IP
terraform init && terraform apply && cd ..

# 2. cluster add-ons
aws eks update-kubeconfig --region ap-south-1 --name testing_k8s
#    EFS CSI driver + AWS Load Balancer Controller: see "Install and Configuration/EFS and LB installation.txt"
#    put `terraform output -raw efs_id` into "Kubernetes with ArgoCD/storageclass.yml", commit, push

# 3. Jenkins: run "Install and Configuration/install-jenkins-server.sh" on the Jenkins EC2,
#    add credential GITHUB_TOKEN, create a pipeline job from SCM (Script Path: Jenkins_cicd/Jenkinsfile),
#    add the GitHub webhook, run the first build

# 4. ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f "Install and Configuration/argocd-application.yaml"
kubectl get ingress -n k8s-project          # open the ALB address

# 5. monitoring
helm upgrade -i monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace \
  -f "Install and Configuration/kube-prometheus-stack-values.yaml" --set grafana.adminPassword='<password>'

# 6. security scans (local)
./Security/scripts/run-security-scans.sh
```

**Teardown:** delete the ArgoCD app and Ingresses first (so the ALBs are removed), uninstall the Helm releases, then run `terraform destroy`. See runbook Phase 11.

## 🔐 Security highlights

- No "all traffic from 0.0.0.0/0" rules. SSH and the monitoring UIs only from `admin_cidr`.
- No static AWS keys on Jenkins (instance profile). Controllers use EKS Pod Identity; least-privilege node role.
- Trivy gates in CI. ECR scan-on-push. Non-root, read-only-rootfs containers.
- Encrypted EBS/EFS/ECR/S3 state, IMDSv2 required.
- Known demo shortcut: `secret.yml` is base64 in Git. Upgrade path with Sealed Secrets is in [`Security/README.md`](Security/README.md).

## 🐛 Troubleshooting

See the [runbook troubleshooting section](docs/RUNBOOK.md#12-troubleshooting) for Terraform, Jenkins, Kubernetes/ArgoCD and monitoring issues.

---

**Note**: This project is for learning and demonstration. Review and adapt the configuration (secrets handling, instance sizes, public endpoints) before using it in production. The EKS control plane, ALBs and EFS are billed hourly, so tear down when you are done.
