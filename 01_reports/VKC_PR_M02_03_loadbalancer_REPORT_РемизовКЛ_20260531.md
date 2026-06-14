---
course_code: VKCLOUD-80
artifact_type: PR
module: 2
task_code: 3
task_title: Настройка балансировщика нагрузки
student_fio: Ремизов Кирилл Львович
date: 2026-05-31
source_docs:
  - 3-Конспект лекций - VK 1.md
  - 4-Практические работы - VK -1.md
commands_used:
  - terraform init
  - terraform plan
  - terraform apply
  - terraform destroy
attached_files:
  - VKC_PR_M02_Balancerpruf_РемизовКЛ_20260531.png
  - VKC_PR_M02_Balancerterraform_РемизовКЛ_20260531.png
  - VKC_PR_M02_Balancer_РемизовКЛ_20260531.png
status: final
---

# Отчет по практической демонстрации

## 1. Цель

Освоить создание сетевой инфраструктуры в VK Cloud: Pазвертывание балансировщика нагрузки для распределения трафика между несколькими веб-серверами. Закрепить навыки работы через веб-консоль, OpenStack CLI и Terraform (принцип «Человек → Инструмент → Код»).

## 2. Что было прочитано перед выполнением

- **Документ:** 3-Конспект лекций - VK 1.md
- **Раздел/тема:** Модуль 2. Сети и виртуальная инфраструктура (пункты 2.1, 2.2, 2.3)
- **Ключевые понятия:**
  - Балансировщик нагрузки (Layer 4/7), Listener, Target Group, Health Checks.
  - OpenStack CLI, Terraform (ресурсы `vkcs_networking_network`, `vkcs_networking_subnet`, `vkcs_networking_secgroup`, `vkcs_lb_*`).

## 3. Ход выполнения

### Настройка балансировщика нагрузки

#### Шаг 1 (Человек — веб-консоль)

**Действие:** Создал две ВМ (`web-1` и `web-2`) с user-data для установки nginx и разными index.html. Создал балансировщик `my-lb` (публичная подсеть), слушатель HTTP:80, целевую группу `web-targets` (ROUND_ROBIN), добавил ВМ, настроил health check (HTTP, путь `/`, интервал 10с).

**Результат:** Балансировщик активен, при обращении по публичному IP чередуются страницы «Web Server 1» и «Web Server 2».

![[VKC_PR_M02_Balancer_РемизовКЛ_20260531.png]]

![[VKC_PR_M02_Balancerpruf_РемизовКЛ_20260531.png]]

#### Шаг 3 (Код — Terraform)

**Действие:** Создал полную конфигурацию `loadbalancer.tf`:
- Сеть `my-vpc` и подсеть `public-subnet`.
- Security groups для web (SSH/HTTP) и для LB (HTTP).
- SSH-ключ `terraform-key`.
- Две ВМ (`web-1`, `web-2`) с user-data для nginx.
- Балансировщик `vkcs_lb_loadbalancer.main`, слушатель `vkcs_lb_listener.http`, пул `vkcs_lb_pool.web`, монитор `vkcs_lb_monitor.web`, члены пула `vkcs_lb_member.web1` и `web2`.

Выполнил `terraform apply`.

```
# Указываем версию провайдера
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

variable "external_network" {
  description = "Имя внешней сети (не используется напрямую, но оставлено для совместимости)"
  type        = string
  default     = "internet"
}

variable "image_name" {
  description = "Имя образа Ubuntu 22.04"
  type        = string
  default     = "ubuntu-22-202602051629.gite7a38aaf"
}

variable "flavor_id" {
  description = "ID флейвора"
  type        = string
  default     = "df3c499a-044f-41d2-8612-d303adc613cc"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "existing_router_id" {
  description = "ID существующего роутера (можно найти в выводе openstack router list)"
  type        = string
  default     = "913bdd47-9155-45b2-b404-5c10d0086132"   # Ваш router_5390
}

data "vkcs_networking_router" "existing" {
  router_id = var.existing_router_id
}

resource "vkcs_networking_network" "main" {
  name           = "my-vpc"
  admin_state_up = true
}

resource "vkcs_networking_subnet" "public" {
  name            = "public-subnet"
  network_id      = vkcs_networking_network.main.id
  cidr            = "192.168.1.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Подключение подсети к существующему роутеру (без создания нового)
resource "vkcs_networking_router_interface" "main" {
  router_id = data.vkcs_networking_router.existing.id
  subnet_id = vkcs_networking_subnet.public.id
}

resource "vkcs_networking_secgroup" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.web_sg.id
}

resource "vkcs_networking_secgroup_rule" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.web_sg.id
}

resource "vkcs_networking_secgroup" "lb_sg" {
  name        = "lb-sg"
  description = "Security group for load balancer"
}

resource "vkcs_networking_secgroup_rule" "lb_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.lb_sg.id
}

resource "vkcs_compute_keypair" "my_key" {
  name       = "terraform-key"
  public_key = file(var.ssh_public_key_path)
}

resource "vkcs_compute_instance" "web1" {
  name        = "web-1"
  flavor_id   = var.flavor_id
  image_name  = var.image_name
  key_pair    = vkcs_compute_keypair.my_key.name

  network {
    uuid = vkcs_networking_network.main.id
  }

  security_groups = [vkcs_networking_secgroup.web_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    apt update
    apt install -y nginx
    echo "<h1>Web Server 1</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
}

resource "vkcs_compute_instance" "web2" {
  name        = "web-2"
  flavor_id   = var.flavor_id
  image_name  = var.image_name
  key_pair    = vkcs_compute_keypair.my_key.name

  network {
    uuid = vkcs_networking_network.main.id
  }

  security_groups = [vkcs_networking_secgroup.web_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    apt update
    apt install -y nginx
    echo "<h1>Web Server 2</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
}

resource "vkcs_lb_loadbalancer" "main" {
  name          = "my-lb"
  vip_subnet_id = vkcs_networking_subnet.public.id
  security_group_ids = [vkcs_networking_secgroup.lb_sg.id]
}

resource "vkcs_lb_listener" "http" {
  name            = "http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = vkcs_lb_loadbalancer.main.id
}

resource "vkcs_lb_pool" "web" {
  name            = "web-targets"
  protocol        = "HTTP"
  lb_method       = "ROUND_ROBIN"
  listener_id     = vkcs_lb_listener.http.id
}

resource "vkcs_lb_monitor" "web" {
  name        = "web-monitor"
  type        = "HTTP"
  delay       = 10
  timeout     = 5
  max_retries = 3
  url_path    = "/"
  pool_id     = vkcs_lb_pool.web.id
}

resource "vkcs_lb_member" "web1" {
  name          = "web1-member"
  address       = vkcs_compute_instance.web1.access_ip_v4
  protocol_port = 80
  pool_id       = vkcs_lb_pool.web.id
  subnet_id     = vkcs_networking_subnet.public.id
}

resource "vkcs_lb_member" "web2" {
  name          = "web2-member"
  address       = vkcs_compute_instance.web2.access_ip_v4
  protocol_port = 80
  pool_id       = vkcs_lb_pool.web.id
  subnet_id     = vkcs_networking_subnet.public.id
}

output "lb_ip" {
  value       = vkcs_lb_loadbalancer.main.vip_address
  description = "Внешний IP-адрес балансировщика"
}

output "web1_ip" {
  value       = vkcs_compute_instance.web1.access_ip_v4
  description = "IP-адрес web-1"
}

output "web2_ip" {
  value       = vkcs_compute_instance.web2.access_ip_v4
  description = "IP-адрес web-2"
}

```

**Результат:** Балансировщик и две ВМ созданы, получены выходные IP-адреса. Приложение доступно по IP балансировщика.

![[VKC_PR_M02_Balancerterraform_РемизовКЛ_20260531.png]]

## 4. Ошибки и исправления

- **Ошибка:** При первом запуске Terraform для балансировщика возникла ошибка `"Router not found"` при создании `vkcs_networking_router_interface`.
- **Причина:** В конфигурации использовался несуществующий ID роутера.
- **Исправление:** Получил актуальный ID роутера через `openstack router list` и подставил в переменную `existing_router_id`. После повторного `terraform apply` интерфейс подключился корректно.

Других ошибок не возникло.

## 5. Критерии успеха

- [x] Две ВМ с nginx запущены, балансировщик создан, целевая группа содержит обе ВМ, health check работает, приложение отвечает по внешнему IP балансировщика, страницы чередуются.

## 6. Приложенные доказательства

| Файл                                                | Тип      | Что подтверждает                                          |
| --------------------------------------------------- | -------- | --------------------------------------------------------- |
| VKC_PR_M02_Balancerpruf_РемизовКЛ_20260531.png      | Скриншот | Факт работы балансировщика с машинами ``web1`` и ``web2`` |
| VKC_PR_M02_Balancer_РемизовКЛ_20260531.png          | Скриншот | Балансировщик `my-lb` и целевая группа                    |
| VKC_PR_M02_Balancerterraform_РемизовКЛ_20260531.png | Скриншот | Terraform apply для балансировщика – выходные IP          |

## 7. Самопроверка

- **Что получилось:**  
  Успешно создал полную сетевую инфраструктуру тремя способами.  Развернул отказоустойчивый веб-сервис с балансировщиком и health checks.

## 8. Краткий вывод

В ходе практической работы были освоены ключевые навыки администрирования сети в VK Cloud: балансировка нагрузки с автоматическим контролем состояния серверов. Работа через веб-консоль, OpenStack CLI и Terraform позволила закрепить принцип «Человек → Инструмент → Код» и понять преимущества декларативного подхода к управлению инфраструктурой.
