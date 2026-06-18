variable "my_ip" {
  description = "Ваш публичный IP для SSH (узнать через curl ifconfig.me)"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Префикс для имен ресурсов"
  type        = string
  default     = "lab3"
}

variable "router_id" {
  description = "ID существующего роутера"
  type        = string
  default     = "913bdd47-9155-45b2-b404-5c10d0086132"
}

variable "external_network_name" {
  description = "Имя внешней сети для Floating IP"
  type        = string
  default     = "internet"
}

variable "ssh_public_key" {
  description = "Путь к публичному SSH-ключу"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "image_name" {
  description = "Имя образа Ubuntu 20.04"
  type        = string
  default     = "ubuntu-20-202602051631.gite7a38aaf"
}

variable "flavor_web" {
  description = "Flavor для веб-серверов (используется только как ID, т.к. загрузка с тома)"
  type        = string
  default     = "Basic-1-1-10"
}

variable "flavor_bastion" {
  description = "Flavor для ВМ бастиона"
  type        = string
  default     = "Basic-1-1-10"
}

variable "public_subnet_cidr" {
  description = "CIDR публичной подсети"
  type        = string
  default     = "192.168.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR приватной подсети"
  type        = string
  default     = "192.168.2.0/24"
}

variable "volume_size_web" {
  description = "Размер диска для веб-серверов (ГБ)"
  type        = number
  default     = 10
}

variable "volume_size_bastion" {
  description = "Размер диска для бастиона (ГБ)"
  type        = number
  default     = 20
}
