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
provider "vkcs" {
  username   = "remizov.kirill2005@yandex.ru"
  password   = "*#Woron210105#*"
  project_id = "5aa354d05172439abcc5bfc3f682da49"
  region     = "RegionOne"               # Для Москвы
  auth_url   = "https://infra.mail.ru:35357/v3/"
}

# --- СУЩЕСТВУЮЩИЙ РОУТЕР ---
data "vkcs_networking_router" "main" {
  name = "router_5390"
}

# --- СОЗДАНИЕ СЕТИ И ПОДСЕТИ ---
resource "vkcs_networking_network" "main" {
  name           = "postgres-network"
  admin_state_up = true
}

resource "vkcs_networking_subnet" "main" {
  name       = "postgres-subnet"
  network_id = vkcs_networking_network.main.id
  cidr       = "192.168.199.0/24"
}

# --- ПОДКЛЮЧЕНИЕ ПОДСЕТИ К РОУТЕРУ ---
resource "vkcs_networking_router_interface" "main" {
  router_id = data.vkcs_networking_router.main.id
  subnet_id = vkcs_networking_subnet.main.id
}

# --- ИНСТАНС POSTGRESQL ---
# ИСПРАВЛЕНО: используем имя флавора для БД (Standard-2-6)
resource "vkcs_db_instance" "postgres" {
  name                = "terraform-postgres"
  flavor_id           = "2df6e3ec-5939-4d28-a818-89558ff1b7ab"      # <-- заменено на подходящий для БД
  volume_type         = "ceph-ssd"
  size                = 10
  availability_zone   = "MS1"
  floating_ip_enabled = true

  datastore {
    type    = "postgresql"
    version = "15"
  }

  network {
    uuid = vkcs_networking_network.main.id
  }
}

# --- ГЕНЕРАЦИЯ ПАРОЛЯ ---
resource "random_password" "db_password" {
  length      = 16
  special     = true
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

# --- БАЗА ДАННЫХ ---
resource "vkcs_db_database" "app_db" {
  name    = "app_db"
  dbms_id = vkcs_db_instance.postgres.id
}

# --- ПОЛЬЗОВАТЕЛЬ ---
resource "vkcs_db_user" "app_user" {
  name      = "app_user"
  password  = random_password.db_password.result
  dbms_id   = vkcs_db_instance.postgres.id
  databases = [vkcs_db_database.app_db.name]
}

# --- ДАННЫЕ ДЛЯ ПОЛУЧЕНИЯ HOSTNAME ---
data "vkcs_db_instance" "postgres_info" {
  id        = vkcs_db_instance.postgres.id
  depends_on = [vkcs_db_instance.postgres]
}

# --- ЛОКАЛЬНЫЙ ФАЙЛ С ПАРОЛЕМ ---
resource "local_file" "db_password" {
  content  = "Database password: ${random_password.db_password.result}"
  filename = "${path.module}/db_password.txt"
}

# --- ВЫХОДНЫЕ ДАННЫЕ ---
output "db_host" {
  value = data.vkcs_db_instance.postgres_info.hostname
}

output "db_port" {
  value = 5432
}

output "db_name" {
  value = vkcs_db_database.app_db.name
}

output "db_user" {
  value = vkcs_db_user.app_user.name
}

output "db_instance_full" {
  value     = data.vkcs_db_instance.postgres_info
  sensitive = true
}
