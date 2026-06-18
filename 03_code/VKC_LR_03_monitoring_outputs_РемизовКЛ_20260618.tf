output "load_balancer_ip" {
  value = vkcs_networking_floatingip.lb.address
  description = "Публичный IP балансировщика"
}

output "bastion_floating_ip" {
  value = vkcs_networking_floatingip.bastion.address
  description = "Публичный IP ВМ бастиона + мониторинга"
}

output "web_private_ips" {
  value = local.web_private_ips
  description = "Приватные IP веб-серверов"
}

output "grafana_url" {
  value = "http://${vkcs_networking_floatingip.bastion.address}:3000"
  description = "URL Grafana"
}

output "prometheus_url" {
  value = "http://${vkcs_networking_floatingip.bastion.address}:9090"
  description = "URL Prometheus"
}

output "ssh_to_bastion" {
  value = "ssh -i ~/.ssh/id_rsa ubuntu@${vkcs_networking_floatingip.bastion.address}"
  description = "Команда для подключения к бастиону"
}
