# Security Tools

Everything security-related for this project lives here. The tools cover each layer of the pipeline:

| Layer | Tool | Where it runs | Blocks the pipeline? |
|---|---|---|---|
| Source code: leaked secrets | Trivy `--scanners secret` | Jenkins stage *Security Scan: Repo*, `scripts/run-security-scans.sh` | **Yes**, on any finding |
| Infrastructure as Code (Terraform, K8s YAML, Dockerfile) | Trivy `config` | Jenkins (report), script | No (report in `reports/`) |
| Python dependencies | Trivy `--scanners vuln` on `requirements.txt` | Jenkins, script | No |
| Container image (OS + Python packages) | Trivy `image` | Jenkins stage *Security Scan: Image*, script | **Yes**, on fixable CRITICAL (toggle `FAIL_ON_CRITICAL`) |
| Registry | ECR scan-on-push | AWS (Terraform `ecr.tf`) | No (ECR console) |
| Cluster configuration | kube-bench (CIS EKS Benchmark) | `kubernetes/kube-bench-job.yml` | No (manual) |
| Pod-to-pod network | Kubernetes NetworkPolicy | `kubernetes/network-policies.yml` | n/a |
| Pod hardening | non-root UID, read-only root FS, no privilege escalation, dropped capabilities | `Kubernetes with ArgoCD/appdeployment.yml`, `Jenkins_cicd/Dockerfile` | n/a |

```
Security/
├── README.md                     this file
├── scripts/
│   └── run-security-scans.sh     run all Trivy scans locally / on Jenkins (only needs Docker)
├── trivy/
│   ├── trivy.yaml                shared Trivy settings (severity, skip dirs)
│   └── .trivyignore              accepted findings, with reason + review date
└── kubernetes/
    ├── network-policies.yml      default-deny + ALB→app + app→db only
    └── kube-bench-job.yml        CIS EKS benchmark job
```

## 1. Scan the repo and image before you push

Only Docker is needed. Every tool runs in a container.

```bash
# repo only: secrets, IaC misconfigurations, dependency CVEs
./Security/scripts/run-security-scans.sh

# repo + a locally built image
docker build -t python_web_application:local Jenkins_cicd
./Security/scripts/run-security-scans.sh python_web_application:local
```

Reports are written to `reports/` (gitignored): `secrets.txt`, `misconfig.txt`, `dependencies.txt`, `image.txt`.
The script exits non-zero if a secret is found or the image has a fixable CRITICAL CVE, the same rule Jenkins applies.

**Accepting a finding:** add its ID to `trivy/.trivyignore` with a comment that explains why and a date to review it. Don't silence findings without a reason.

## 2. Security in the Jenkins pipeline

`Jenkins_cicd/Jenkinsfile` runs the same scans with the `aquasec/trivy` container (nothing to install on Jenkins):

1. **Security Scan: Repo** fails on secrets and archives the IaC/dependency report as `reports/trivy-repo.txt`.
2. **Security Scan: Image** archives the HIGH/CRITICAL report as `reports/trivy-image.txt` and fails the build before push if a fixable CRITICAL exists.

Both stages can be switched off per build with the `RUN_SECURITY_SCANS` parameter (*Build with Parameters*). The image gate can be relaxed with `FAIL_ON_CRITICAL`.
Reports appear under each build's **Artifacts**.

The Trivy vulnerability DB is cached in the Docker volume `trivy-cache` on the Jenkins server, so only the first run downloads it.

## 3. NetworkPolicies (zero-trust inside the cluster)

Terraform enables the VPC CNI network policy agent (`enableNetworkPolicy` in `Terraform/eks/eks.tf`), so policies are enforced.

```bash
kubectl apply -f Security/kubernetes/network-policies.yml
kubectl get networkpolicy -n k8s-project

# verify: the app still works through the ALB ...
curl -I http://$(kubectl get ingress myapp-ingress -n k8s-project -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/
# ... and a random pod can no longer reach MySQL (should time out)
kubectl run nettest -n k8s-project --rm -it --image=busybox:1.36 --restart=Never -- nc -zv -w 3 mydb 3306
```

When it works, move the file into `Kubernetes with ArgoCD/` so ArgoCD manages it.

## 4. CIS benchmark with kube-bench

```bash
mkdir -p reports
kubectl apply -f Security/kubernetes/kube-bench-job.yml
kubectl wait --for=condition=complete job/kube-bench -n kube-system --timeout=180s
kubectl logs job/kube-bench -n kube-system > reports/kube-bench.txt
grep -E "^\[(FAIL|WARN)\]" reports/kube-bench.txt | head -30
kubectl delete -f Security/kubernetes/kube-bench-job.yml
```

## 5. Pod Security Standards (namespace level)

Have Kubernetes warn about any pod in `k8s-project` that breaks the *restricted* profile:

```bash
kubectl label namespace k8s-project \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted --overwrite
```

The app Deployment already meets *restricted*. The MySQL StatefulSet triggers warnings (it doesn't drop capabilities), so stay with `warn`/`audit` rather than `enforce`.

## 6. AWS-side hardening already in Terraform

- **Security groups:** no more "all traffic from 0.0.0.0/0". SSH and the monitoring UIs are limited to `admin_cidr` (set your IP in `terraform.tfvars`). Only Jenkins `8080` is public, because GitHub webhooks need it.
- **EC2:** IMDSv2 required, encrypted gp3 root volumes.
- **EKS worker nodes:** least-privilege IAM (removed EC2/ELB/ECR *FullAccess*). Controllers use **EKS Pod Identity** roles.
- **ECR:** scan on push, encryption, lifecycle policy (keeps the last 20 images).
- **EFS:** encrypted at rest, NFS only from the EKS security groups.
- **Terraform state:** S3 backend with encryption and native S3 locking (`use_lockfile`).

Optional, AWS-native threat detection (the free trial is 30 days, then it's paid):

```bash
aws guardduty create-detector --enable --region ap-south-1 \
  --features '[{"Name":"EKS_AUDIT_LOGS","Status":"ENABLED"}]'
```

## 7. Secrets: known limitation and upgrade path

`Kubernetes with ArgoCD/secret.yml` is only base64-encoded and sits in a public repo, which is fine for a demo but not for real use.
The upgrade path is **Sealed Secrets**: only the cluster can decrypt them, and the encrypted file is safe to commit.

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm upgrade -i sealed-secrets sealed-secrets/sealed-secrets -n kube-system
# install the kubeseal CLI: https://github.com/bitnami-labs/sealed-secrets/releases

kubectl create secret generic my-secret -n k8s-project --dry-run=client -o yaml \
  --from-literal=DB_PASSWORD='<new-password>' \
  --from-literal=MYSQL_ROOT_PASSWORD='<new-password>' \
  --from-literal=DJANGO_SECRET_KEY="$(openssl rand -base64 48)" \
| kubeseal --controller-namespace kube-system --format yaml > "Kubernetes with ArgoCD/sealed-secret.yml"

git rm "Kubernetes with ArgoCD/secret.yml"
git add "Kubernetes with ArgoCD/sealed-secret.yml" && git commit -m "Use SealedSecret for app credentials"
```

> MySQL only reads `MYSQL_ROOT_PASSWORD` the first time it starts on an empty volume. On an existing database, change the password inside MySQL first (`ALTER USER 'root'@'%' IDENTIFIED BY '...'`), then update the secret.

Never commit: AWS access keys, GitHub tokens, the Gmail app password, the Grafana admin password, `terraform.tfvars`, `*.tfstate`. They are in `.gitignore`, and the Trivy secret scan catches common token formats.
