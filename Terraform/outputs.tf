output "region" {
  value = "ap-south-1"
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  description = "Used by the AWS Load Balancer Controller Helm install"
  value       = module.vpc.vpc_id
}

output "efs_id" {
  description = "Put this in Kubernetes with ArgoCD/storageclass.yml (fileSystemId)"
  value       = module.efs.efs_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "server_public_ips" {
  description = "Jenkins and Prometheus/Grafana servers"
  value       = module.ec2.public_ips
}

output "server_private_ips" {
  value = module.ec2.private_ips
}

output "acm_certificate_arn" {
  description = "Use in the ingress certificate-arn annotation when domain_name is set"
  value       = module.dns.certificate_arn
}

output "route53_name_servers" {
  description = "Set these as the name servers at your domain registrar when domain_name is set"
  value       = module.dns.name_servers
}

output "jenkins_public_ip" {
  value = module.ec2.public_ips["Jenkins"]
}

output "monitoring_public_ip" {
  value = module.ec2.public_ips["Prometheus and Grafana"]
}
