terraform {
  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "vkcs" {
  username   = var.vkcs_username
  password   = var.vkcs_password
  project_id = var.vkcs_project_id
  region     = var.vkcs_region
  auth_url   = var.vkcs_auth_url
}

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

# --- Сеть ---
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

# --- Security Groups ---
resource "vkcs_networking_secgroup" "main" {
  name        = "${var.project_name}-secgroup"
  description = "Security group for VMs"
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

resource "vkcs_networking_secgroup_rule" "egress" {
  security_group_id = vkcs_networking_secgroup.main.id
  direction         = "egress"
  remote_ip_prefix  = "0.0.0.0/0"
}

# Security Group для базы данных
resource "vkcs_networking_secgroup" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for PostgreSQL"
}

resource "vkcs_networking_secgroup_rule" "db_ingress" {
  security_group_id = vkcs_networking_secgroup.db_sg.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_ip_prefix  = var.private_subnet_cidr
}

# --- Key Pair ---
resource "vkcs_compute_keypair" "my_key" {
  name       = "${var.project_name}-key"
  public_key = file(var.ssh_public_key)
}

# --- Веб-серверы (Docker, без логина) ---
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

  # user_data – без логина, просто run
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Установка Docker
    apt-get update
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
    
    # Ждём, пока Docker-демон полностью запустится
    sleep 5
      
    # Запускаем контейнер с повторными попытками, если образ не скачался
    MAX_ATTEMPTS=5
    ATTEMPT=0
    until [ $ATTEMPT -ge $MAX_ATTEMPTS ]
    do
      echo "Attempt $((ATTEMPT+1)): pulling and running container..."
      docker run -d --restart=always -p 80:80 ${var.docker_image} && break
      ATTEMPT=$((ATTEMPT+1))
      echo "Failed. Retrying in 10 seconds..."
      sleep 10
    done
    
    # Если после всех попыток контейнер не запустился – пишем ошибку в лог
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
      echo "ERROR: Failed to run container after $MAX_ATTEMPTS attempts." >&2
      exit 1
    fi
    
    echo "Container started successfully."
  EOF
}

locals {
  web_private_ips = vkcs_compute_instance.web[*].network[0].fixed_ip_v4
}

# --- Балансировщик ---
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
  url_path    = "/DevOps"
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

# --- Бастион (без мониторинга) ---
resource "vkcs_compute_instance" "bastion" {
  name               = "${var.project_name}-bastion"
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
    apt-get update
    apt-get install -y curl wget htop
  EOF
}

resource "vkcs_networking_floatingip" "bastion" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_networking_floatingip_associate" "bastion" {
  floating_ip = vkcs_networking_floatingip.bastion.address
  port_id     = vkcs_compute_instance.bastion.network[0].port
}

# --- Управляемая PostgreSQL ---
resource "vkcs_db_instance" "postgres" {
  name        = "${var.project_name}-postgres"
  flavor_id   = "bf714720-78da-4271-ab7d-0cf5e2613f14"   # Standard-2-8-50
  size        = 10
  volume_type = "ceph-ssd"
  network {
    subnet_id = vkcs_networking_subnet.private.id
  }
  availability_zone = "MS1"
  datastore {
    type    = "postgresql"
    version = "14"
  }
}

resource "vkcs_db_database" "app_db" {
  dbms_id = vkcs_db_instance.postgres.id
  name    = "app_db"
}

resource "vkcs_db_user" "app_user" {
  dbms_id  = vkcs_db_instance.postgres.id
  name     = "app_user"
  password = "*#User23786590#*"
}
