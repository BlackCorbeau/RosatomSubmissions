# Указываем версию провайдера
terraform {
  required_providers {
    vkcs = {
      source = "vk-cs/vkcs"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# Настройка провайдера (использует переменные окружения из RC-файла)
provider "vkcs" {}

# Переменные
variable "my_ip" {
  description = "Your public IP for SSH access"
  type        = string
  sensitive   = false
}

variable "project_name" {
  default = "my-project"
}

# 1. Сеть
resource "vkcs_networking_network" "main" {
  name = "${var.project_name}-network"
}

resource "vkcs_networking_subnet" "public" {
  name       = "${var.project_name}-public-subnet"
  network_id = vkcs_networking_network.main.id
  cidr       = "192.168.1.0/24"
}

# 2. Security Groups (исправлено: vkcs_networking_secgroup + правила)
resource "vkcs_networking_secgroup" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Web server security group"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "${var.my_ip}/32"
  security_group_id = vkcs_networking_secgroup.web.id
}

resource "vkcs_networking_secgroup_rule" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.web.id
}

# 3. SSH ключ
resource "vkcs_compute_keypair" "main" {
  name       = "${var.project_name}-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# 4. Веб-серверы
resource "vkcs_compute_instance" "web" {
  count = 2

  name        = "${var.project_name}-web-${count.index + 1}"
  flavor_id = "df3c499a-044f-41d2-8612-d303adc613cc"
  image_id    = "a4e699d3-a66d-45e5-bb5d-70ea7c8de62d"
  key_pair    = vkcs_compute_keypair.main.name

  network {
    uuid = vkcs_networking_network.main.id
  }

  security_groups = [vkcs_networking_secgroup.web.name]

  user_data = <<-EOF
    #!/bin/bash
    apt update
    apt install -y nginx
    echo "<h1>Web Server ${count.index + 1}</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
}

# 5. Балансировщик
resource "vkcs_lb_loadbalancer" "main" {
  name          = "${var.project_name}-lb"
  vip_subnet_id = vkcs_networking_subnet.public.id
}

resource "vkcs_lb_listener" "http" {
  name            = "${var.project_name}-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = vkcs_lb_loadbalancer.main.id
}

resource "vkcs_lb_pool" "web" {
  name        = "${var.project_name}-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = vkcs_lb_listener.http.id
}

resource "vkcs_lb_monitor" "web" {
  name        = "${var.project_name}-monitor"
  type        = "HTTP"
  delay       = 10
  timeout     = 5
  max_retries = 3
  url_path    = "/"
  pool_id     = vkcs_lb_pool.web.id
}

resource "vkcs_lb_member" "web" {
  count = 2

  name          = "${var.project_name}-member-${count.index + 1}"
  address       = vkcs_compute_instance.web[count.index].access_ip_v4
  protocol_port = 80
  pool_id       = vkcs_lb_pool.web.id
  subnet_id     = vkcs_networking_subnet.public.id
}

# 6. Выходные данные
output "load_balancer_ip" {
  value = vkcs_lb_loadbalancer.main.vip_address
}

output "web_servers_ips" {
  value = vkcs_compute_instance.web[*].access_ip_v4
}
