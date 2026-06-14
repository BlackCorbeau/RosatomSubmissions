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
