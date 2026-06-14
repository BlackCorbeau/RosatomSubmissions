resource "vkcs_networking_secgroup" "bastion_sg" {
  name        = "bastion-sg"
  description = "SSH from my IP"
}
resource "vkcs_networking_secgroup_rule" "bastion_ssh" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.my_ip
  security_group_id = vkcs_networking_secgroup.bastion_sg.id
}

resource "vkcs_networking_secgroup" "web_sg" {
  name        = "web-sg"
  description = "SSH from bastion, HTTP from LB"
}
resource "vkcs_networking_secgroup_rule" "web_ssh" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = vkcs_networking_secgroup.bastion_sg.id
  security_group_id = vkcs_networking_secgroup.web_sg.id
}
resource "vkcs_networking_secgroup_rule" "web_http" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = vkcs_networking_secgroup.lb_sg.id
  security_group_id = vkcs_networking_secgroup.web_sg.id
}

resource "vkcs_networking_secgroup" "lb_sg" {
  name        = "lb-sg"
  description = "HTTP from internet"
}
resource "vkcs_networking_secgroup_rule" "lb_http" {
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.lb_sg.id
}
