output "lb_public_ip" {
  value = vkcs_lb_loadbalancer.main.vip_address
}

# bastion_ip и web_ips_private удали, так как ВМ больше не в Terraform
