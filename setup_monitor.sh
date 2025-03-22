#!/bin/bash

# Update system packages
echo "Updating system packages..."
sudo apt update -y && sudo apt upgrade -y

# Install Docker
echo "Installing Docker..."
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker 

# Create Prometheus directory
echo "Setting up Prometheus..."
mkdir -p ~/prometheus
cd ~/prometheus

# Download Prometheus
PROM_VERSION="2.51.2"
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
mv prometheus-${PROM_VERSION}.linux-amd64 prometheus
rm prometheus-${PROM_VERSION}.linux-amd64.tar.gz

# Create Prometheus config
cat <<EOF > ~/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['YOUR_NODE_IP_1:9100', 'YOUR_NODE_IP_2:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['YOUR_NODE_IP_1:8080', 'YOUR_NODE_IP_2:8080']
EOF

# Run Prometheus in Docker
echo "Starting Prometheus..."
docker run -d --name=prometheus \
  -p 9090:9090 \
  -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Install and Run Grafana
echo "Installing and starting Grafana..."
docker run -d --name=grafana \
  -p 3000:3000 \
  grafana/grafana

echo "Installation complete. Access Grafana at http://YOUR_EC2_IP:3000 and Prometheus at http://YOUR_EC2_IP:9090"
