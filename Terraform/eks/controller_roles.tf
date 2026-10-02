// IAM roles for in-cluster controllers, granted through EKS Pod Identity.
// AL2023 nodes block pod access to the instance metadata service, so the
// controllers cannot borrow the node role and need their own credentials.

locals {
  pod_identity_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# EFS CSI driver (Helm release aws-efs-csi-driver)
resource "aws_iam_role" "efs_csi_role" {
  name               = "Terraform_AmazonEKSPodIdentityEFSCSIRole"
  assume_role_policy = local.pod_identity_trust
}

resource "aws_iam_role_policy_attachment" "efs_csi_policy" {
  role       = aws_iam_role.efs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "efs_csi" {
  cluster_name    = aws_eks_cluster.main_eks.name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi_role.arn
  depends_on      = [aws_eks_addon.pod_identity_agent]
}

# AWS Load Balancer Controller (Helm release aws-load-balancer-controller)
# Policy from https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.5.0/docs/install/iam_policy.json
resource "aws_iam_policy" "lb_controller_policy" {
  name   = "Terraform_AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/lb_controller_iam_policy.json")
}

resource "aws_iam_role" "lb_controller_role" {
  name               = "Terraform_AmazonEKSPodIdentityLBControllerRole"
  assume_role_policy = local.pod_identity_trust
}

resource "aws_iam_role_policy_attachment" "lb_controller_policy" {
  role       = aws_iam_role.lb_controller_role.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = aws_eks_cluster.main_eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller_role.arn
  depends_on      = [aws_eks_addon.pod_identity_agent]
}
