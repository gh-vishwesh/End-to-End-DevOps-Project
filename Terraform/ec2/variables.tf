variable "instance_ami" {
  default = "ami-02bf0feb29433c907"
}

variable "instance_type" {
    default = "t3.micro"
}

variable "ec2_name" {
    default = ["Jenkins","Prometheus and Grafana"]
}

variable "vpc_id" {
  
}

variable "subnet_id" {  
}

variable "ec2_ingress_rule" {
    type = map(object({
        port = number
        protocol = string
        cidr_block = list(string)
        description = string
    }))
}

variable "key" {
}

variable "ec2_sg"{
    default = {
        Name ="sg"
    }
}
