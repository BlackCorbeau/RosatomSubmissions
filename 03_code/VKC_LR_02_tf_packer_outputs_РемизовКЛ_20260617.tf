output "lb_public_ip" {
  value = vkcs_lb_loadbalancer.main.vip_address
  description = "Публичный IP балансировщика"
}

output "bastion_public_ip" {
  value = vkcs_networking_floatingip.bastion_fip.address
}

output "web_private_ips" {
  value = vkcs_compute_instance.web[*].network[0].fixed_ip_v4
  description = "Приватные IP веб-серверов"
}
