variable "my_ip" {
  type    = string
  default = "95.26.148.233/32"
}

variable "flavor_web" {
  type    = string
  default = "25ae869c-be29-4840-8e12-99e046d2dbd4"
}

variable "flavor_bastion" {
  type    = string
  default = "df3c499a-044f-41d2-8612-d303adc613cc"
}

variable "image_packer_id" {
  type    = string
  default = "a31acc16-4703-468b-bc5b-bf07952f66b2"
}

variable "ubuntu_image_name" {
  type    = string
  default = "ubuntu-22-202602051629.gite7a38aaf"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "keypair_name" {
  type    = string
  default = "terraform-key-local"
}

variable "ubuntu_image_id" {
  type    = string
  default = "a4e699d3-a66d-45e5-bb5d-70ea7c8de62d"
}

variable "db_flavor_id" {
  type    = string
  default = "2d9866a9-e955-4986-b00a-340ca54b2cac"
}
