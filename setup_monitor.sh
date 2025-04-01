#!/bin/bash

# Update system packages
echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y && sudo apt upgrade -y

# Install Docker
echo "Installing Docker..."
sudo apt install -y docker.io git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Apply group change immediately
export DOCKER_GROUP_ID=$(getent group docker | cut -d: -f3)
sudo newgrp docker <<EONG
    echo "Reloading user groups..."
    sudo usermod -aG docker $USER
EONG

# Install Ansible
echo "Installing Ansible..."
sudo apt remove --purge ansible -y
sudo apt update && sudo apt install -y python3-pip
pip3 install ansible

# Download Prometheus
PROM_VERSION="2.51.2"
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
mv prometheus-${PROM_VERSION}.linux-amd64 prometheus
rm prometheus-${PROM_VERSION}.linux-amd64.tar.gz

git clone https://github.com/lhes23/monitoring-server.git

# Run Prometheus in Docker (Using sudo to avoid logout issues)
echo "Starting Prometheus..."
sudo docker run -d --name=prometheus \
  -p 9090:9090 \
  -v ~/monitoring-server/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Install and Run Grafana (Using sudo)
echo "Installing and starting Grafana..."
sudo docker run -d --name=grafana \
  -p 3000:3000 \
  grafana/grafana


PUBLIC_IP=$(curl -s http://icanhazip.com)

echo "Installation complete!"
echo "Access Grafana at http://${PUBLIC_IP}:3000"
echo "Access Prometheus at http://${PUBLIC_IP}:9090"

# Prompt user to run Ansible playbook manually
echo "Copy the .pem file to the ~/.ssh directory"
echo "scp -i ~/.ssh/ec2-users-key-us-east.pem ~/.ssh/ec2-users-key-us-east.pem ubuntu@${PUBLIC_IP}:~/.ssh/."
echo "To install playbook, run: ansible-playbook -i ~/monitoring-server/ansible/inventory.ini ~/monitoring-server/playbook.yml"


cat <<EOF > ./run_command.txt
scp -i ~/.ssh/ec2-users-key-us-east.pem ~/.ssh/ec2-users-key-us-east.pem ubuntu@${PUBLIC_IP}:~/.ssh/.
ansible-playbook -i ~/monitoring-server/ansible/inventory.ini ~/monitoring-server/ansible/playbook.yml
EOF