resource "vkcs_compute_keypair" "my_key" {
  name       = var.keypair_name
  public_key = file(var.ssh_public_key_path)
}

resource "vkcs_networking_port" "bastion_port" {
  name           = "bastion-port"
  network_id     = vkcs_networking_network.lab1_vpc.id
  admin_state_up = true

  fixed_ip {
    subnet_id = vkcs_networking_subnet.public.id      
  }

  security_group_ids = [vkcs_networking_secgroup.bastion_sg.id]
}

resource "vkcs_compute_instance" "bastion" {
  name            = "bastion"
  flavor_id       = var.flavor_bastion
  image_id        = var.ubuntu_image_id
  key_pair        = vkcs_compute_keypair.my_key.name

  network {
    port = vkcs_networking_port.bastion_port.id
  }
}

resource "vkcs_networking_floatingip" "bastion_fip" {
  pool = "internet"
}

resource "vkcs_compute_floatingip_associate" "bastion_fip_assoc" {
  floating_ip = vkcs_networking_floatingip.bastion_fip.address
  instance_id = vkcs_compute_instance.bastion.id
}

resource "vkcs_networking_port" "web_port" {
  count = 2
  name  = "web-port-${count.index + 1}"
  network_id = vkcs_networking_network.lab1_vpc.id
  admin_state_up = true

  fixed_ip {
    subnet_id = vkcs_networking_subnet.private.id
  }

  security_group_ids = [vkcs_networking_secgroup.web_sg.id]
}

resource "vkcs_compute_instance" "web" {
  count  = 2
  name   = "web-${count.index + 1}"
  flavor_id = var.flavor_web
  image_id  = var.image_packer_id
  key_pair  = vkcs_compute_keypair.my_key.name

  network {
    port = vkcs_networking_port.web_port[count.index].id
  }
}
