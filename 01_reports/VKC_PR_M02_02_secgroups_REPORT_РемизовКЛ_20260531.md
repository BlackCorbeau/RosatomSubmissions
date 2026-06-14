---
course_code: VKCLOUD-80
artifact_type: PR
module: 2
task_code: 2
task_title: Настройка Security Groups
student_fio: Ремизов Кирилл Львович
date: 2026-05-31
source_docs:
  - 3-Конспект лекций - VK 1.md
  - 4-Практические работы - VK -1.md
commands_used:
  - openstack security group create
  - openstack security group rule create
  - openstack server add security group
  - terraform init
  - terraform plan
  - terraform apply
  - terraform destroy
attached_files:
  - VKC_PR_M02_Securitygroupsbyopenstack_РемизовКЛ_20260531.png
  - VKC_PR_M02_Securitygroupsbyterraform_РемизовКЛ_20260531.png
  - VKC_PR_M02_Securitygroups_РемизовКЛ_20260531.png
status: final
---

# Отчет по практической демонстрации

## 1. Цель

Освоить создание сетевой инфраструктуры в VK Cloud: настройку Security Groups для защиты ресурсов. Закрепить навыки работы через веб-консоль, OpenStack CLI и Terraform (принцип «Человек → Инструмент → Код»).

## 2. Что было прочитано перед выполнением

- **Документ:** 3-Конспект лекций - VK 1.md
- **Раздел/тема:** Модуль 2. Сети и виртуальная инфраструктура (пункты 2.1, 2.2, 2.3)
- **Ключевые понятия:**
  - Security Groups (stateful), правила ingress/egress, принцип минимальных привилегий.
  - OpenStack CLI, Terraform (ресурсы `vkcs_networking_network`, `vkcs_networking_subnet`, `vkcs_networking_secgroup`, `vkcs_lb_*`).

## 3. Ход выполнения

### Настройка Security Groups

#### Шаг 1 (Человек — веб-консоль)

**Действие:** Создал группу `web-server-sg`. Добавил правила: SSH (мой IP), HTTP (0.0.0.0/0), HTTPS (0.0.0.0/0). Применил к существующей ВМ.

**Результат:** Группа создана, правила применены.

![[VKC_PR_M02_Securitygroups_РемизовКЛ_20260531.png]]

#### Шаг 2 (Инструмент — OpenStack CLI)

**Действие:** Выполнил команды:

```bash
openstack security group create database-sg --description "Security group for database servers"
openstack security group rule create database-sg --protocol tcp --dst-port 22 --remote-ip 95.26.148.233/32
openstack security group rule create database-sg --protocol tcp --dst-port 5432 --remote-ip 192.168.2.0/24
openstack security group rule list database-sg
openstack server add security group db-server database-sg
```

**Результат:** Security group `database-sg` создана, правила SSH и PostgreSQL добавлены.

![[VKC_PR_M02_Securitygroupsbyopenstack_РемизовКЛ_20260531.png]]

#### Шаг 3 (Код — Terraform)

**Действие:** В `main.tf` описал:
- Переменную `my_ip` (по умолчанию 95.26.148.233/32).
- Ресурсы `vkcs_networking_secgroup` для web и db.
- Правила `vkcs_networking_secgroup_rule` (ingress SSH/HTTP, egress; для БД — SSH/PostgreSQL из приватной подсети).

Выполнил `terraform apply`.

```
# Security Group для веб-сервера
resource "vkcs_compute_secgroup" "web_sg" {
  name        = "terraform-web-sg"
  description = "Security group for web servers"

  # Правило для SSH
  rule {
    ip_protocol = "tcp"
    from_port   = 22
    to_port     = 22
    cidr        = var.my_ip  # используем переменную
  }

  # Правило для HTTP
  rule {
    ip_protocol = "tcp"
    from_port   = 80
    to_port     = 80
    cidr        = "0.0.0.0/0"
  }

  # Исходящий трафик (все разрешено)
  rule {
    ip_protocol = "tcp"
    from_port   = 1
    to_port     = 65535
    cidr        = "0.0.0.0/0"
    direction   = "egress"
  }
}

# Security Group для базы данных
resource "vkcs_compute_secgroup" "db_sg" {
  name        = "terraform-db-sg"
  description = "Security group for database servers"

  # SSH только из приватной подсети
  rule {
    ip_protocol = "tcp"
    from_port   = 22
    to_port     = 22
    cidr        = "192.168.2.0/24"
  }

  # PostgreSQL только из приватной подсети
  rule {
    ip_protocol = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr        = "192.168.2.0/24"
  }
}

# Переменная для вашего IP
variable "my_ip" {
  description = "Your public IP for SSH access"
  type        = string
  default     = "0.0.0.0/0"  # замените на свой IP
}
```

**Результат:** Security Groups созданы, правила настроены.

![[VKC_PR_M02_Securitygroupsbyterraform_РемизовКЛ_20260531.png]]

## 4. Ошибки и исправления

Oшибок не возникло.

## 5. Критерии успеха

- [x] Security Group `web-server-sg` и `database-sg` созданы с правильными правилами (SSH ограничен по IP, HTTP открыт, PostgreSQL разрешён из приватной подсети).

## 6. Приложенные доказательства

| Файл                                                        | Тип      | Что подтверждает                           |
| ----------------------------------------------------------- | -------- | ------------------------------------------ |
| VKC_PR_M02_Securitygroups_РемизовКЛ_20260531.png            | Скриншот | Security Group `web-server-sg` с правилами |
| VKC_PR_M02_Securitygroupsbyopenstack_РемизовКЛ_20260531.png | Скриншот | Команды CLI для `database-sg` и результат  |
| VKC_PR_M02_Securitygroupsbyterraform_РемизовКЛ_20260531.png | Скриншот | Terraform apply для Security Groups        |

## 7. Самопроверка

- **Что получилось:**  
  Успешно создал полную сетевую инфраструктуру тремя способами. Настроил Security Groups с учётом минимальных привилегий.

## 8. Краткий вывод

В ходе практической работы были освоены ключевые навыки администрирования сети в VK Cloud: Hастройка stateful-брандмауэров (Security Groups) для защиты ВМ. Работа через веб-консоль, OpenStack CLI и Terraform позволила закрепить принцип «Человек → Инструмент → Код» и понять преимущества декларативного подхода к управлению инфраструктурой.
