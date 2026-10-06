#!/usr/bin/env bash
# One-shot setup for the Jenkins EC2 (Ubuntu 24.04): Docker, AWS CLI v2, Java 21, Jenkins, swap.
# Usage (on the Jenkins server):  sudo bash install-jenkins-server.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "Run with sudo"; exit 1; fi

echo ">>> Base packages"
apt-get update -y
apt-get install -y ca-certificates curl gnupg unzip git fontconfig

echo ">>> 2 GB swap (Jenkins + docker build + Trivy on a small instance)"
if ! swapon --show | grep -q /swapfile; then
    fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo ">>> Docker Engine (official repo)"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo ">>> AWS CLI v2"
if ! command -v aws >/dev/null; then
    tmp=$(mktemp -d)
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp/awscliv2.zip"
    unzip -q "$tmp/awscliv2.zip" -d "$tmp"
    "$tmp/aws/install"
    rm -rf "$tmp"
fi

echo ">>> Java 21 + Jenkins LTS"
apt-get install -y openjdk-21-jre
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

echo ">>> Let Jenkins use Docker"
usermod -aG docker jenkins
systemctl enable jenkins
systemctl restart jenkins

echo
echo "Versions:"; docker --version; aws --version; java -version 2>&1 | head -1
echo
echo "Jenkins is starting on http://<this-server-public-ip>:8080"
echo "Initial admin password:"
for i in $(seq 1 30); do [ -f /var/lib/jenkins/secrets/initialAdminPassword ] && break; sleep 2; done
cat /var/lib/jenkins/secrets/initialAdminPassword
