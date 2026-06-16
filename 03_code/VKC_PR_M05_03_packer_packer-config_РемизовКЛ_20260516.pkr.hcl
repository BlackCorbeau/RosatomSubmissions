# Переменные окружения
variable "network_id" {
  type    = string
  default = env("NETWORK_ID")
}
variable "source_image" {
  type    = string
  default = env("SOURCE_IMAGE")
}

packer {
  required_plugins {
    openstack = {
      source  = "github.com/hashicorp/openstack"
      version = ">= 1.1.2"
    }
  }
}

source "openstack" "ubuntu-nginx" {
  flavor       = "STD3-2-6"
  source_image = var.source_image
  networks     = [var.network_id]          # используем сеть internet
  ssh_username = "ubuntu"
  image_name   = "nginx-custom-image-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  use_blockstorage_volume = true
  volume_availability_zone = "MS1"
  config_drive = true
  security_groups = ["ssh"]
  ssh_keypair_name     = "postgress-test-ViPomgZ4"
  ssh_private_key_file = "./postgress-test-ViPomgZ4.pem"
  ssh_timeout          = "10m"
}

build {
  sources = ["source.openstack.ubuntu-nginx"]

  provisioner "shell" {
    inline = [
      # Фикс hostname для sudo
      "sudo sh -c 'echo \"127.0.0.1 $(hostname)\" >> /etc/hosts'",

      # Принудительная настройка DNS с блокировкой от перезаписи
      "sudo rm -f /etc/resolv.conf",
      "sudo sh -c 'echo nameserver 8.8.8.8 > /etc/resolv.conf'",
      "sudo sh -c 'echo nameserver 1.1.1.1 >> /etc/resolv.conf'",
      "sudo chattr +i /etc/resolv.conf",   # защита от перезаписи

      # Обновление списка пакетов (обязательно!)
      "echo 'Updating package lists...'",
      "sudo apt-get update",

      "echo 'Installing nginx...'",
      "sudo apt-get install -y nginx",

      "echo 'Configuring nginx...'",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",

      "echo 'Creating test page...'",
      "echo '<h1>Hello from Packer!</h1>' | sudo tee /var/www/html/index.html",

      "echo 'Cleaning up...'",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/lib/apt/lists/*"
    ]
  }
}
