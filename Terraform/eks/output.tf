output "security_group" {
  value = aws_security_group.eks_SG.id
}


# EKS-managed security group attached to the worker nodes
output "cluster_security_group" {
  value = aws_eks_cluster.main_eks.vpc_config[0].cluster_security_group_id
}
