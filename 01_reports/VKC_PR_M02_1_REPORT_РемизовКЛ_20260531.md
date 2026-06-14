---
course_code: VKCLOUD-80
artifact_type: PR
module: 2
task_code: 1
task_title: Сети и виртуальная инфраструктура
student_fio: Ремизов Кирилл Львович
date: 2026-05-31
source_docs:
  - 3-Конспект лекций - VK 1.md
  - 4-Практические работы - VK -1.md
commands_used:
  - openstack network create
  - openstack subnet create
  - openstack router create
  - openstack router set
  - openstack router add subnet
  - terraform init
  - terraform plan
  - terraform apply
  - terraform destroy
attached_files:
  - VKC_PR_M02_NetworksCard_РемизовКЛ_20260531.png
  - VKC_PR_M02_terraformNetworkCreating_РемизовКЛ_20260531.png
  - VKC_PR_M02_VPCandSubnets_РемизовКЛ_20260531.png
  - VKC_PR_M02_VPCbyOpenstack_РемизовКЛ_20260531.png
status: final
---

# Отчет по практической демонстрации

## 1. Цель

Освоить создание сетевой инфраструктуры в VK Cloud: проектирование VPC с публичными и приватными подсетями. Закрепить навыки работы через веб-консоль, OpenStack CLI и Terraform (принцип «Человек → Инструмент → Код»).

## 2. Что было прочитано перед выполнением

- **Документ:** 3-Конспект лекций - VK 1.md
- **Раздел/тема:** Модуль 2. Сети и виртуальная инфраструктура (пункты 2.1, 2.2, 2.3)
- **Ключевые понятия:**
  - VPC, публичные/приватные подсети, CIDR, DHCP, интернет-шлюз, роутер.
  - OpenStack CLI, Terraform (ресурсы `vkcs_networking_network`, `vkcs_networking_subnet`, `vkcs_networking_secgroup`, `vkcs_lb_*`).

## 3. Ход выполнения

### Демонстрация 2.1: Создание VPC и подсетей

#### Шаг 1 (Человек — веб-консоль)

**Действие:** Создал VPC `my-vpc`, добавил публичную подсеть `public-subnet` (CIDR 192.168.1.0/24) с выходом в интернет и приватную подсеть `private-subnet` (CIDR 192.168.2.0/24) без доступа в интернет. Проверил таблицу маршрутизации.

**Результат:** VPC и подсети успешно созданы.

![[VKC_PR_M02_VPCandSubnets_РемизовКЛ_20260531.png]]

![[VKC_PR_M02_NetworksCard_РемизовКЛ_20260531.png]]

#### Шаг 2 (Инструмент — OpenStack CLI)

**Действие:** Выполнил команды (используя RC-файл):

```bash
openstack network create my-vpc-cli
openstack subnet create public-subnet-cli --network my-vpc-cli --subnet-range 192.168.1.0/24 --gateway 192.168.1.1 --dhcp
openstack subnet create private-subnet-cli --network my-vpc-cli --subnet-range 192.168.2.0/24 --gateway 192.168.2.1 --dhcp
openstack router create my-router
openstack router set my-router --external-gateway ext-net
openstack router add subnet my-router public-subnet-cli
```

**Результат:** Сеть, подсети и роутер созданы, интерфейс роутера подключён к публичной подсети.

![[VKC_PR_M02_VPCbyOpenstack_РемизовКЛ_20260531.png]]

#### Шаг 3 (Код — Terraform)

**Действие:** Написал `network.tf` с ресурсами:
- `vkcs_networking_network.main`
- `vkcs_networking_subnet.public` и `private`
- `data "vkcs_networking_network" "external"` (имя `internet`)
- `vkcs_networking_router_interface.public` (с использованием существующего роутера)
```
# Создание VPC (сети)
resource "vkcs_networking_network" "main" {
  name           = "terraform-vpc"
  admin_state_up = true
}

# Создание публичной подсети
resource "vkcs_networking_subnet" "public" {
  name       = "terraform-public-subnet"
  network_id = vkcs_networking_network.main.id
  cidr       = "192.168.1.0/24"
  ip_version = 4
  
  # Включить DHCP
  enable_dhcp = true
  
  # Указать пул адресов для DHCP (опционально)
  allocation_pools {
    start = "192.168.1.10"
    end   = "192.168.1.200"
  }
}

# Создание приватной подсети
resource "vkcs_networking_subnet" "private" {
  name       = "terraform-private-subnet"
  network_id = vkcs_networking_network.main.id
  cidr       = "192.168.2.0/24"
  ip_version = 4
  enable_dhcp = true
}

# Создание роутера для доступа в интернет
resource "vkcs_networking_router" "router" {
  name                = "terraform-router"
  admin_state_up      = true
  
  # Внешняя сеть (предоставляется провайдером)
  external_network_id = data.vkcs_networking_network.external.id
}

# Data source для поиска внешней сети
data "vkcs_networking_network" "external" {
  name = "ext-net"  # имя внешней сети в VK Cloud
}

# Подключение публичной подсети к роутеру
resource "vkcs_networking_router_interface" "public" {
  router_id = vkcs_networking_router.router.id
  subnet_id = vkcs_networking_subnet.public.id
}

# Для приватной подсети НЕ создаем интерфейс к роутеру
# (она будет изолирована)

# Вывод информации
output "network_id" {
  value = vkcs_networking_network.main.id
}

output "public_subnet_id" {
  value = vkcs_networking_subnet.public.id
}

output "private_subnet_id" {
  value = vkcs_networking_subnet.private.id
}
```

Выполнил:
```bash
terraform init
terraform plan
terraform apply
```

**Результат:** VPC и подсети созданы, интерфейс роутера подключён. Получены `network_id`, `public_subnet_id`, `private_subnet_id`.

![[VKC_PR_M02_terraformNetworkCreating_РемизовКЛ_20260531.png]]

## 4. Ошибки и исправления

Ошибок не возникло.

## 5. Критерии успеха

- [x] VPC `my-vpc` создана, публичная и приватная подсети присутствуют, роутер настроен (интерфейс в публичной подсети).

## 6. Приложенные доказательства

| Файл                                                       | Тип      | Что подтверждает                           |
| ---------------------------------------------------------- | -------- | ------------------------------------------ |
| VKC_PR_M02_VPCbyOpenstack_РемизовКЛ_20260531.png           | Скриншот | Создание VPC и подсетей (консоль)          |
| VKC_PR_M02_NetworksCard_РемизовКЛ_20260531.png             | Скриншот | Список подсетей после создания             |
| VKC_PR_M02_VPCandSubnets_РемизовКЛ_20260531.png            | Скриншот | Успешное создание сети и роутера через CLI |
| VKC_PR_M02_terraformNetworkCreating_РемизовКЛ_20260531.png | Скриншот | Применение Terraform для VPC и подсетей    |

## 7. Самопроверка

- **Что получилось:**  
  Успешно создал полную сетевую инфраструктуру тремя способами.

- **Что осталось непонятным:**  
  Как сделать пункт 2.1.1 корректно 

## 8. Краткий вывод

В ходе практической работы были освоены ключевые навыки администрирования сети в VK Cloud: создание изолированной VPC с публичной и приватной подсетями. Работа через веб-консоль, OpenStack CLI и Terraform позволила закрепить принцип «Человек → Инструмент → Код» и понять преимущества декларативного подхода к управлению инфраструктурой.
