variable "my_ip" {
  type    = string
  default = "95.37.52.68/32"
}

variable "flavor_web" {
  type    = string
  default = "df3c499a-044f-41d2-8612-d303adc613cc"
}

variable "image_name" {
  type    = string
  default = "ubuntu-22-202602051629.gite7a38aaf"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}
