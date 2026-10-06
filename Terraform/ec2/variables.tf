variable "instance_ami" {
  description = "AMI to use; empty means latest Ubuntu 24.04"
  default     = ""
}

variable "ec2_name" {
  default = ["Jenkins", "Prometheus and Grafana"]
}

# One entry per name above. Jenkins builds Docker images and runs Trivy, which needs more than 1 GB RAM.
variable "instance_types" {
  default = ["t3.small", "t3.micro"]
}

variable "root_volume_size" {
  default = 20
}

variable "vpc_id" {

}

variable "subnet_id" {
}

variable "ec2_ingress_rule" {
  type = map(object({
    port        = number
    protocol    = string
    cidr_block  = list(string)
    description = string
  }))
}

variable "key" {
}

variable "ec2_sg" {
  default = {
    Name = "sg"
  }
}
