output "public_ips" {
  value = { for i, inst in aws_instance.ec2 : var.ec2_name[i] => inst.public_ip }
}

output "private_ips" {
  value = { for i, inst in aws_instance.ec2 : var.ec2_name[i] => inst.private_ip }
}
