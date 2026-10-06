locals {
  vpc_cidr = "10.0.0.0/16" # must match vpc/variable.tf cidr_block
}

module "vpc" {
  source = "./vpc"
}

module "ec2" {
  source    = "./ec2"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.subnet_ids
  key       = var.key_name
  ec2_ingress_rule = {
    "SSH" = {
      port        = 22
      protocol    = "tcp"
      cidr_block  = [var.admin_cidr]
      description = "SSH from admin"
    }
    # GitHub webhooks must reach Jenkins, so 8080 stays open; Jenkins login protects the UI
    "Jenkins" = {
      port        = 8080
      protocol    = "tcp"
      cidr_block  = ["0.0.0.0/0"]
      description = "Jenkins UI and GitHub webhook"
    }
    "Prometheus" = {
      port        = 9090
      protocol    = "tcp"
      cidr_block  = [var.admin_cidr]
      description = "Prometheus UI"
    }
    "Alertmanager" = {
      port        = 9093
      protocol    = "tcp"
      cidr_block  = [var.admin_cidr]
      description = "Alertmanager UI"
    }
    "Grafana" = {
      port        = 3000
      protocol    = "tcp"
      cidr_block  = [var.admin_cidr]
      description = "Grafana UI"
    }
    # Prometheus scraping node_exporter/pushgateway/Jenkins between the two servers
    "VPC" = {
      port        = 0
      protocol    = "-1"
      cidr_block  = [local.vpc_cidr]
      description = "All traffic inside the VPC"
    }
  }
}

module "dns" {
  source      = "./Route53_ACM"
  domain_name = var.domain_name
}

module "eks" {
  source   = "./eks"
  vpc_id   = module.vpc.vpc_id
  sub_ids  = module.vpc.subnet_ids
  key_name = var.key_name
  eks_ingress_rule = {
    "VPC" = {
      port        = 0
      protocol    = "-1"
      cidr_block  = [local.vpc_cidr]
      description = "All traffic inside the VPC"
    }
    "SSH" = {
      port        = 22
      protocol    = "tcp"
      cidr_block  = [var.admin_cidr]
      description = "SSH from admin"
    }
  }
  depends_on = [module.ec2]
}

module "efs" {
  source     = "./efs"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.subnet_ids
  efs_ingress_rule = {
    "efs_inbound" = {
      port           = 2049
      protocol       = "TCP"
      cidr_blocks    = []
      description    = "Allow NFS access from EKS nodes"
      security_group = [module.eks.security_group, module.eks.cluster_security_group]
    }
  }
  depends_on = [module.eks]
}

module "ecr" {
  source = "./ecr"
}
