# Copy to terraform.tfvars (gitignored) and adjust, then run terraform plan/apply.
admin_cidr  = "203.0.113.10/32" # your public IP: curl -s ifconfig.me
key_name    = "vishwesh-EC2"    # existing EC2 key pair in ap-south-1
domain_name = ""                # e.g. "app.example.com" to enable Route 53 + ACM (HTTPS)
