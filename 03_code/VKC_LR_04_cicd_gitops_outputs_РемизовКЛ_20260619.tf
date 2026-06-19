output "load_balancer_ip" {
  value = vkcs_networking_floatingip.lb.address
  description = "Публичный IP балансировщика"
}

output "web_private_ips" {
  value = local.web_private_ips
  description = "Приватные IP веб-серверов"
}

output "lb_url" {
  value = "http://${vkcs_networking_floatingip.lb.address}"
  description = "URL для доступа к приложению"
}
