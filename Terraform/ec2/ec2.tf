# Latest Ubuntu 24.04 LTS AMI, so the config doesn't break when a hardcoded AMI is deprecated
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "ec2" {
  count                       = length(var.ec2_name)
  ami                         = var.instance_ami != "" ? var.instance_ami : data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = var.instance_types[count.index]
  subnet_id                   = var.subnet_id[count.index]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = var.key
  tags = {
    Name = var.ec2_name[count.index]
  }
  iam_instance_profile = aws_iam_instance_profile.jenkins_instance.name

  # Docker images, Jenkins workspaces and the Trivy DB need more than the 8 GB default
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  # IMDSv2 only; hop limit 2 so containers on the host (docker builds) can still reach it
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_iam_instance_profile" "jenkins_instance" {
  name = "jenkins_instance"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "ec2_sg" {
  name        = "Ec2"
  description = "Jenkins and monitoring servers"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ec2_ingress_rule
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_block
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.ec2_sg
}
