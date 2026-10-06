# Goes into "Kubernetes with ArgoCD/storageclass.yml" (fileSystemId)
output "efs_id" {
  value = aws_efs_file_system.eks_efs.id
}
