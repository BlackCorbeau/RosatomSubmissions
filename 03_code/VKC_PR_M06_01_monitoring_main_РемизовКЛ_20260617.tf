terraform {
  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.1"
    }
  }
}

provider "vkcs" {}

variable "external_network_name" {
  default = "internet"
}

variable "router_id" {
  default = "913bdd47-9155-45b2-b404-5c10d0086132"
}

variable "image_name" {
  default = "ubuntu-20-202602051631.gite7a38aaf"
}

variable "flavor_name" {
  default = "Basic-1-2-20"
}

variable "app_count" {
  default = 1
}

variable "availability_zone" {
  default = "MS1"
}

data "vkcs_networking_network" "extnet" {
  name = var.external_network_name
}

data "vkcs_networking_router" "router" {
  id = var.router_id
}

data "vkcs_images_image" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

data "vkcs_compute_flavor" "vm" {
  name = var.flavor_name
}

resource "vkcs_networking_network" "internal" {
  name = "monitoring-internal-net"
  sdn  = "sprut"
}

resource "vkcs_networking_subnet" "internal" {
  name        = "monitoring-internal-subnet"
  network_id  = vkcs_networking_network.internal.id
  cidr        = "192.168.200.0/24"
}

resource "vkcs_networking_router_interface" "router_interface" {
  router_id = data.vkcs_networking_router.router.id
  subnet_id = vkcs_networking_subnet.internal.id
}

resource "vkcs_networking_secgroup" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Allow SSH, Prometheus, Grafana, Node Exporter"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.monitoring_sg.id
}

resource "vkcs_networking_secgroup_rule" "grafana" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.monitoring_sg.id
}

resource "vkcs_networking_secgroup_rule" "prometheus" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9090
  port_range_max    = 9090
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.monitoring_sg.id
}

resource "vkcs_networking_secgroup_rule" "node_exporter" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9100
  port_range_max    = 9100
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.monitoring_sg.id
}

resource "vkcs_compute_keypair" "monitoring" {
  name       = "monitoring-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "vkcs_compute_instance" "app" {
  count = var.app_count

  name               = "app-vm-${count.index + 1}"
  flavor_id          = data.vkcs_compute_flavor.vm.id
  key_pair           = vkcs_compute_keypair.monitoring.name
  availability_zone  = var.availability_zone

  block_device {
    uuid                  = data.vkcs_images_image.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_type           = "ceph-ssd"
    volume_size           = 10
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = vkcs_networking_network.internal.id
  }

  security_groups = [vkcs_networking_secgroup.monitoring_sg.name]

  user_data = <<-EOF
#!/bin/bash
set -e
apt-get update
apt-get install -y wget
cd /opt
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*
cat > /etc/systemd/system/node_exporter.service <<EOL
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=nobody
Group=nogroup
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
EOL
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
echo "App VM ${count.index + 1} ready"
EOF
}

resource "vkcs_compute_instance" "monitoring" {
  depends_on = [vkcs_compute_instance.app]

  name               = "monitoring-vm"
  flavor_id          = data.vkcs_compute_flavor.vm.id
  key_pair           = vkcs_compute_keypair.monitoring.name
  availability_zone  = var.availability_zone

  block_device {
    uuid                  = data.vkcs_images_image.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_type           = "ceph-ssd"
    volume_size           = 10
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = vkcs_networking_network.internal.id
  }

  security_groups = [vkcs_networking_secgroup.monitoring_sg.name]

  user_data = <<-EOF
#!/bin/bash
set -e
exec > >(tee /var/log/user_data.log) 2>&1

# --- Устанавливаем пароль для ubuntu ---
echo "ubuntu:debian" | chpasswd

# --- Включаем парольный SSH ---
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# --- Установка Prometheus, Grafana, Node Exporter ---
apt-get update
apt-get install -y wget curl software-properties-common

cd /opt
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar xvf prometheus-2.48.0.linux-amd64.tar.gz
mv prometheus-2.48.0.linux-amd64 prometheus
useradd --no-create-home --shell /bin/false prometheus
chown -R prometheus:prometheus /opt/prometheus

# Создаём папку для данных и даём права
mkdir -p /opt/prometheus/data
chown -R prometheus:prometheus /opt/prometheus/data

cat > /opt/prometheus/prometheus.yml <<EOL
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: []
EOL

cat > /etc/systemd/system/prometheus.service <<EOL
[Unit]
Description=Prometheus
After=network.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --web.listen-address=0.0.0.0:9090 --storage.tsdb.path=/opt/prometheus/data
Restart=always
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# --- Grafana (установка через deb, чтобы избежать проблем с репозиторием) ---
cd /tmp
wget https://dl.grafana.com/oss/release/grafana_11.3.0_amd64.deb
dpkg -i grafana_11.3.0_amd64.deb || apt-get install -f -y
systemctl enable grafana-server
systemctl start grafana-server

# --- Node Exporter ---
cd /opt
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*

cat > /etc/systemd/system/node_exporter.service <<EOL
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=nobody
Group=nogroup
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "=== user_data finished ==="
EOF
}

resource "vkcs_networking_floatingip" "monitoring_fip" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_compute_floatingip_associate" "monitoring_fip_assoc" {
  floating_ip = vkcs_networking_floatingip.monitoring_fip.address
  instance_id = vkcs_compute_instance.monitoring.id
}

output "monitoring_ip" {
  value = vkcs_networking_floatingip.monitoring_fip.address
}

output "app_ips" {
  value = vkcs_compute_instance.app[*].access_ip_v4
}

output "grafana_url" {
  value = "http://${vkcs_networking_floatingip.monitoring_fip.address}:3000"
}

output "prometheus_url" {
  value = "http://${vkcs_networking_floatingip.monitoring_fip.address}:9090"
}

output "ssh_password" {
  value     = "debian"
  description = "Логин: ubuntu, пароль: debian"
}
