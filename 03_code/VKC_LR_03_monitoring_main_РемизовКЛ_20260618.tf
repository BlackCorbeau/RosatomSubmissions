terraform {
  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.1"
    }
  }
}

# Настройка провайдера (использует переменные окружения из RC-файла)
provider "vkcs" {}

data "vkcs_networking_network" "extnet" {
  name = var.external_network_name
}

data "vkcs_networking_secgroup" "ssh" {
  name = "ssh"
}

data "vkcs_networking_router" "router" {
  id = var.router_id
}

data "vkcs_images_image" "ubuntu" {
  name = var.image_name
}

data "vkcs_compute_flavor" "web" {
  name = var.flavor_web
}

data "vkcs_compute_flavor" "bastion" {
  name = var.flavor_bastion
}

resource "vkcs_networking_network" "main" {
  name = "${var.project_name}-network"
  sdn  = "sprut"
}

resource "vkcs_networking_subnet" "public" {
  name        = "${var.project_name}-public-subnet"
  network_id  = vkcs_networking_network.main.id
  cidr        = var.public_subnet_cidr
  dns_nameservers = ["8.8.8.8", "1.1.1.1"]
}

resource "vkcs_networking_subnet" "private" {
  name        = "${var.project_name}-private-subnet"
  network_id  = vkcs_networking_network.main.id
  cidr        = var.private_subnet_cidr
  dns_nameservers = ["8.8.8.8", "1.1.1.1"]
}

resource "vkcs_networking_router_interface" "public" {
  router_id = data.vkcs_networking_router.router.id
  subnet_id = vkcs_networking_subnet.public.id
}

resource "vkcs_networking_router_interface" "private" {
  router_id = data.vkcs_networking_router.router.id
  subnet_id = vkcs_networking_subnet.private.id
}

resource "vkcs_networking_secgroup" "main" {
  name        = "${var.project_name}-secgroup"
  description = "Security group for monitoring lab"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "${var.my_ip}/32"
}

resource "vkcs_networking_secgroup_rule" "http" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "vkcs_networking_secgroup_rule" "prometheus" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 9090
  port_range_max    = 9090
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "vkcs_networking_secgroup_rule" "grafana" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "vkcs_networking_secgroup_rule" "node_exporter_public" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 9100
  port_range_max    = 9100
  remote_ip_prefix  = var.public_subnet_cidr
}

resource "vkcs_networking_secgroup_rule" "node_exporter_private" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 9100
  port_range_max    = 9100
  remote_ip_prefix  = var.private_subnet_cidr
}

resource "vkcs_networking_secgroup_rule" "egress" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "egress"
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "vkcs_compute_keypair" "my_key" {
  name       = "${var.project_name}-key"
  public_key = file(var.ssh_public_key)
}

resource "vkcs_compute_instance" "web" {
  count = 2
  name               = "${var.project_name}-web-${count.index + 1}"
  flavor_id          = data.vkcs_compute_flavor.web.id
  key_pair           = vkcs_compute_keypair.my_key.name
  security_group_ids = [vkcs_networking_secgroup.main.id, data.vkcs_networking_secgroup.ssh.id]
  availability_zone  = "MS1"

  block_device {
    uuid                  = data.vkcs_images_image.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_type           = "ceph-ssd"
    volume_size           = var.volume_size_web
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid        = vkcs_networking_network.main.id
    fixed_ip_v4 = cidrhost(var.private_subnet_cidr, count.index + 10)
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt update
    apt install -y nginx

    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html>
    <head><title>Web Server $(hostname)</title></head>
    <body>
        <h1>Welcome to $(hostname)</h1>
        <p>Server IP: $(hostname -I | awk '{print $1}')</p>
    </body>
    </html>
    HTML

    systemctl enable nginx
    systemctl start nginx

    # Node Exporter
    cd /tmp
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xf node_exporter-1.7.0.linux-amd64.tar.gz
    sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter-1.7.0.linux-amd64*

    cat <<SERVICE > /etc/systemd/system/node_exporter.service
    [Unit]
    Description=Node Exporter
    After=network.target
    [Service]
    Type=simple
    User=nobody
    Group=nogroup
    ExecStart=/usr/local/bin/node_exporter
    Restart=always
    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
  EOF
}

locals {
  web_private_ips = vkcs_compute_instance.web[*].network[0].fixed_ip_v4
}

resource "vkcs_lb_loadbalancer" "main" {
  name           = "${var.project_name}-lb"
  vip_subnet_id  = vkcs_networking_subnet.public.id
}

resource "vkcs_lb_listener" "http" {
  name            = "${var.project_name}-listener"
  loadbalancer_id = vkcs_lb_loadbalancer.main.id
  protocol        = "HTTP"
  protocol_port   = 80
}

resource "vkcs_lb_pool" "web" {
  name        = "${var.project_name}-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = vkcs_lb_listener.http.id
}

resource "vkcs_lb_monitor" "web" {
  pool_id     = vkcs_lb_pool.web.id
  type        = "HTTP"
  url_path    = "/"
  delay       = 10
  timeout     = 5
  max_retries = 3
}

resource "vkcs_lb_member" "web" {
  count = 2
  pool_id = vkcs_lb_pool.web.id
  address = local.web_private_ips[count.index]
  protocol_port = 80
  subnet_id = vkcs_networking_subnet.private.id
}

resource "vkcs_networking_floatingip" "lb" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_networking_floatingip_associate" "lb" {
  floating_ip = vkcs_networking_floatingip.lb.address
  port_id     = vkcs_lb_loadbalancer.main.vip_port_id
}

resource "vkcs_compute_instance" "bastion" {
  name               = "${var.project_name}-bastion-monitoring"
  flavor_id          = data.vkcs_compute_flavor.bastion.id
  key_pair           = vkcs_compute_keypair.my_key.name
  security_group_ids = [vkcs_networking_secgroup.main.id, data.vkcs_networking_secgroup.ssh.id]
  availability_zone  = "MS1"

  block_device {
    uuid                  = data.vkcs_images_image.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_type           = "ceph-ssd"
    volume_size           = var.volume_size_bastion
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid        = vkcs_networking_network.main.id
    fixed_ip_v4 = cidrhost(var.public_subnet_cidr, 10)
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # ---- Prometheus ----
    cd /tmp
    wget -q https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
    tar xf prometheus-2.48.0.linux-amd64.tar.gz
    sudo mv prometheus-2.48.0.linux-amd64 /opt/prometheus

    sudo mkdir -p /opt/prometheus/data
    sudo chown -R nobody:nogroup /opt/prometheus/data

    cat <<PROM > /opt/prometheus/prometheus.yml
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    rule_files:
      - "rules/*.yml"
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'node'
        static_configs:
          - targets:
            - 'localhost:9100'
    ${join("\n", [for ip in local.web_private_ips : "            - '${ip}:9100'"])}
    PROM

    cat <<SERVICE > /etc/systemd/system/prometheus.service
    [Unit]
    Description=Prometheus
    After=network.target
    [Service]
    Type=simple
    User=nobody
    Group=nogroup
    ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data
    Restart=always
    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus

    # ---- Grafana (прямая установка) ----
    cd /tmp
    wget -q https://dl.grafana.com/oss/release/grafana_10.4.0_amd64.deb
    sudo apt-get update
    sudo apt-get install -y musl libfontconfig1 fontconfig-config fonts-dejavu-core
    sudo dpkg -i grafana_10.4.0_amd64.deb || sudo apt-get install -f -y
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server

    # ---- Node Exporter для самой ВМ ----
    cd /tmp
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xf node_exporter-1.7.0.linux-amd64.tar.gz
    sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter-1.7.0.linux-amd64*

    cat <<NEX > /etc/systemd/system/node_exporter.service
    [Unit]
    Description=Node Exporter
    After=network.target
    [Service]
    Type=simple
    User=nobody
    Group=nogroup
    ExecStart=/usr/local/bin/node_exporter
    Restart=always
    [Install]
    WantedBy=multi-user.target
    NEX

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter

    # ---- Alertmanager ----
    cd /tmp
    wget -q https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz
    tar xf alertmanager-0.26.0.linux-amd64.tar.gz
    sudo mv alertmanager-0.26.0.linux-amd64 /opt/alertmanager

    cat <<AM > /opt/alertmanager/alertmanager.yml
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'null'
    receivers:
      - name: 'null'
    AM

    cat <<AMS > /etc/systemd/system/alertmanager.service
    [Unit]
    Description=Alertmanager
    After=network.target
    [Service]
    Type=simple
    User=nobody
    Group=nogroup
    ExecStart=/opt/alertmanager/alertmanager --config.file=/opt/alertmanager/alertmanager.yml
    Restart=always
    [Install]
    WantedBy=multi-user.target
    AMS

    systemctl daemon-reload
    systemctl enable alertmanager
    systemctl start alertmanager

    # ---- Правила алертов ----
    sudo mkdir -p /opt/prometheus/rules
    cat <<RULES > /opt/prometheus/rules/alerts.yml
    groups:
      - name: instance_alerts
        rules:
          - alert: InstanceDown
            expr: up{job="node"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Instance {{ \$labels.instance }} is down"
              description: "{{ \$labels.instance }} has been down for more than 5 minutes."
    RULES

    systemctl restart prometheus
  EOF
}

resource "vkcs_networking_floatingip" "bastion" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_networking_floatingip_associate" "bastion" {
  floating_ip = vkcs_networking_floatingip.bastion.address
  port_id     = vkcs_compute_instance.bastion.network[0].port
}
