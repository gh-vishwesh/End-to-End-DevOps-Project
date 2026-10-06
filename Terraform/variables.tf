variable "admin_cidr" {
  description = "CIDR allowed to SSH and open the monitoring UIs. Set it to your own IP, e.g. \"203.0.113.10/32\" (curl ifconfig.me)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_name" {
  description = "Existing EC2 key pair used for SSH to the Jenkins/monitoring servers and EKS nodes"
  type        = string
  default     = "vishwesh-EC2"
}

variable "domain_name" {
  description = "Optional domain for Route 53 + ACM (HTTPS on the ALB). Leave empty to skip DNS/certificate."
  type        = string
  default     = ""
}
