output "load_balancer_ip" {
  value = vkcs_networking_floatingip.lb.address
  description = "Публичный IP балансировщика"
}

output "bastion_floating_ip" {
  value = vkcs_networking_floatingip.bastion.address
  description = "Публичный IP ВМ бастиона"
}

output "web_private_ips" {
  value = local.web_private_ips
  description = "Приватные IP веб-серверов"
}

output "ssh_to_bastion" {
  value = "ssh -i ~/.ssh/id_rsa ubuntu@${vkcs_networking_floatingip.bastion.address}"
  description = "Команда для подключения к бастиону"
}

output "db_host" {
  value = vkcs_db_instance.postgres.network[0].fixed_ip_v4
  description = "Приватный IP инстанса PostgreSQL"
}

output "db_name" {
  value = vkcs_db_database.app_db.name
  description = "Имя базы данных"
}

output "db_user" {
  value = vkcs_db_user.app_user.name
  description = "Имя пользователя БД"
}
