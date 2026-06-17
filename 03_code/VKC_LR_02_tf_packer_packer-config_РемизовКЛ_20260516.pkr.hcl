# Переменные окружения
variable "network_id" {
  type    = string
  default = env("NETWORK_ID")
}
variable "source_image" {
  type    = string
  default = env("SOURCE_IMAGE")
}

source "openstack" "ubuntu-nginx" {
  flavor       = "STD3-2-6"
  source_image = var.source_image
  networks     = [var.network_id]
  ssh_username = "ubuntu"
  image_name   = "nginx-custom-image-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  config_drive = true
  security_groups = ["ssh"]
  ssh_keypair_name     = "postgress-test-ViPomgZ4"
  ssh_private_key_file = "./postgress-test-ViPomgZ4.pem"
  ssh_timeout          = "10m"
}

build {
  sources = ["source.openstack.ubuntu-nginx"]
}
