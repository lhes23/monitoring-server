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

# Apply group change immediately
export DOCKER_GROUP_ID=$(getent group docker | cut -d: -f3)
sudo newgrp docker <<EONG
    echo "Reloading user groups..."
    sudo usermod -aG docker $USER
EONG

# Install Ansible
echo "Installing Ansible..."
sudo apt install -y ansible

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
cat <<EOT > ~/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['NODE_1_IP:9100', 'NODE_2_IP:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['NODE_1_IP:8080', 'NODE_2_IP:8080']
EOT

# Run Prometheus in Docker (Using sudo to avoid logout issues)
echo "Starting Prometheus..."
sudo docker run -d --name=prometheus \
  -p 9090:9090 \
  -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Install and Run Grafana (Using sudo)
echo "Installing and starting Grafana..."
sudo docker run -d --name=grafana \
  -p 3000:3000 \
  grafana/grafana

# Return to home directory
cd ~

# Create Ansible Inventory File
echo "Creating Ansible inventory file..."
cat <<EOT > ~/ansible_inventory.ini
[all]
node1 ansible_host=NODE_1_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/YOUR_KEY.pem
node2 ansible_host=NODE_2_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/YOUR_KEY.pem
EOT

# Create Ansible Playbook for Node Exporter
echo "Creating Ansible playbook for Node Exporter..."
cat <<EOT > ~/install_node_exporter.yml
---
- name: Install Node Exporter on EC2 instances
  hosts: all
  become: yes
  tasks:
    - name: Update system packages
      apt:
        update_cache: yes

    - name: Create a node_exporter user
      user:
        name: node_exporter
        shell: /usr/sbin/nologin
        system: yes
        create_home: no

    - name: Download Node Exporter
      get_url:
        url: "https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz"
        dest: "/tmp/node_exporter.tar.gz"

    - name: Extract Node Exporter
      unarchive:
        src: "/tmp/node_exporter.tar.gz"
        dest: "/usr/local/bin/"
        remote_src: yes
        extra_opts: [--strip-components=1]

    - name: Set permissions for Node Exporter
      file:
        path: "/usr/local/bin/node_exporter"
        owner: node_exporter
        group: node_exporter
        mode: '0755'

    - name: Create Node Exporter service file
      copy:
        dest: "/etc/systemd/system/node_exporter.service"
        content: |
          [Unit]
          Description=Node Exporter
          After=network.target

          [Service]
          User=node_exporter
          ExecStart=/usr/local/bin/node_exporter
          Restart=always

          [Install]
          WantedBy=multi-user.target

    - name: Reload systemd daemon
      systemd:
        daemon_reload: yes

    - name: Enable and start Node Exporter
      systemd:
        name: node_exporter
        enabled: yes
        state: started
EOT

echo "Installation complete!"
echo "Access Grafana at http://YOUR_EC2_IP:3000"
echo "Access Prometheus at http://YOUR_EC2_IP:9090"

# Prompt user to run Ansible playbook manually
echo "To install Node Exporter, run: ansible-playbook -i ~/ansible_inventory.ini ~/install_node_exporter.yml"
echo "Don't forget to replace NODE_1_IP and NODE_2_IP with your EC2 instances' IPs"