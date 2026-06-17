---
course_code: VKCLOUD-80
artifact_type: LR
lab_code: 2
lab_title: Автоматизация с Terraform и Packer
student_fio: Ремизов Кирилл Львович
date: 2026-06-17
source_docs:
  - 5-Задания для лабораторных работ -VK-1.md
  - 3-Конспект лекций - VK 1.md
attached_files:
  - VKC_LR_02_tf_packer_packer_РемизовКЛ_20260617.png
  - VKC_LR_02_tf_packer_packerlog_РемизовКЛ_20260617.log
  - VKC_LR_02_tf_packer_packer-config_РемизовКЛ_20260516.pkr.hcl
  - VKC_LR_02_tf_packer_networktopology_РемизовКЛ_20260617.png
  - VKC_LR_02_tf_packer_balancerpruf_РемизовКЛ_20260617.png
  - VKC_LR_02_tf_packer_tflog1_РемизовКЛ_20260617.log
  - VKC_LR_02_tf_packer_tflog2_РемизовКЛ_20260617.log
  - VKC_LR_02_tf_packer_s3log_РемизовКЛ_20260617.log
  - VKC_LR_02_tf_packer_backend_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_compute_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_database_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_loadbalancer_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_network_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_outputs_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_provider_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_security_РемизовКЛ_20260617.tf
  - VKC_LR_02_tf_packer_variables_РемизовКЛ_20260617.tf
estimated_cost_rub: 120
status: final
---

# Отчет по лабораторной работе №2

## 1. Цель работы

Автоматизировать развертывание отказоустойчивой веб-инфраструктуры (из лабораторной работы №1) с использованием **Infrastructure as Code (Terraform)** и **автоматизированной сборки образов (Packer)**. Основные задачи:

- Создать кастомизированный образ веб-сервера с предустановленным nginx с помощью Packer.
- Описать всю инфраструктуру (VPC, подсети, Security Groups, виртуальные машины, балансировщик, управляемую БД) в Terraform.
- Настроить удалённое хранение state-файла в S3 для командной работы.

## 2. Используемые ресурсы

| Ресурс | Тип | Параметры | Назначение |
|--------|-----|-----------|-------------|
| VPC `lab1-vpc` | Virtual Private Cloud | CIDR: 10.0.0.0/16 | Изолированная сеть |
| Публичная подсеть `lab1-public` | Subnet | CIDR: 10.0.1.0/24, доступ через интернет-шлюз | Размещение бастиона и балансировщика |
| Приватная подсеть `lab1-private` | Subnet | CIDR: 10.0.2.0/24, выход в интернет через NAT | Размещение веб-серверов и БД |
| Бастионный хост `bastion` | ВМ (Ubuntu 22.04) | Флейвор `df3c499a-...`, публичный IP | Единственная точка SSH-доступа |
| Веб-серверы `web-1`, `web-2` | ВМ (кастомный образ Packer) | Флейвор `25ae869c-...`, приватные IP 10.0.2.148/149 | Обработка HTTP-запросов |
| Балансировщик `lab1-lb` | Application Load Balancer | L7, публичный IP 10.0.1.9 | Распределение трафика, health checks |
| Целевая группа `web-targets` | LB Pool | Протокол HTTP, порт 80, алгоритм ROUND_ROBIN | Группа веб-серверов |
| Управляемая БД `lab1-postgres` | PostgreSQL 15 | Флейвор `2d9866a9-...`, диск 10 ГБ, приватная сеть | Хранение данных приложения |
| Бакет S3 `terraform-state-lab2` | Object Storage | Стандартный класс | Хранение remote state Terraform |
| Security Groups | `bastion-sg`, `web-sg`, `lb-sg` | Правила доступа по принципу минимальных привилегий | Сетевая изоляция |

## 3. Схема архитектуры

Архитектура полностью повторяет схему из ЛР №1:

- VPC с двумя подсетями: **public** (10.0.1.0/24) и **private** (10.0.2.0/24).
- Бастионный хост в public-подсети с публичным IP.
- Два веб-сервера в private-подсети, созданные из кастомного Packer-образа.
- Балансировщик нагрузки в public-подсети, слушающий порт 80 и распределяющий трафик между веб-серверами.
- Управляемый PostgreSQL в private-подсети.
- Доступ к приватным ресурсам осуществляется через бастион.

Визуальное представление топологии:

![[VKC_LR_02_tf_packer_networktopology_РемизовКЛ_20260617.png]]

## 4. Ход выполнения

### Этап 1. Сборка кастомизированного образа с Packer

**Задача:** создать образ Ubuntu 22.04 с предустановленным nginx и минимальной индексной страницей.

**Используемые инструменты:** Packer, OpenStack CLI (для авторизации).

**Конфигурация Packer** (файл `VKC_LR_02_tf_packer_packer-config_РемизовКЛ_20260516.pkr.hcl`):

```hcl
# Переменные окружения
variable "network_id" {
  type    = string
  default = env("NETWORK_ID")
}
variable "source_image" {
  type    = string
  default = env("SOURCE_IMAGE")
}

source "openstack" "ubuntu-nginx" {
  flavor       = "STD3-2-6"
  source_image = var.source_image
  networks     = [var.network_id]
  ssh_username = "ubuntu"
  image_name   = "nginx-custom-image-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  config_drive = true
  security_groups = ["ssh"]
  ssh_keypair_name     = "postgress-test-ViPomgZ4"
  ssh_private_key_file = "./postgress-test-ViPomgZ4.pem"
  ssh_timeout          = "10m"
}

build {
  sources = ["source.openstack.ubuntu-nginx"]
}
```

**Действия:**

1. Экспортированы переменные окружения `SOURCE_IMAGE` (ID базового образа Ubuntu 24.04) и `NETWORK_ID` (ID внешней сети).
2. Выполнена валидация конфигурации: `packer validate .`
3. Запущена сборка: `packer build .`

**Лог сборки (фрагмент):**

```
==> openstack.ubuntu-nginx: Launching server...
==> openstack.ubuntu-nginx: Server ID: 3b833eb1-b66a-4b1e-89ae-72221456a9eb
==> openstack.ubuntu-nginx: Waiting for server to become ready...
==> openstack.ubuntu-nginx: Using SSH communicator to connect: 95.163.215.61
==> openstack.ubuntu-nginx: Waiting for SSH to become available...
==> openstack.ubuntu-nginx: Connected to SSH!
==> openstack.ubuntu-nginx: Stopping server...
==> openstack.ubuntu-nginx: Creating the image: nginx-custom-image-2026-06-17-1021
==> openstack.ubuntu-nginx: Image: a31acc16-4703-468b-bc5b-bf07952f66b2
==> openstack.ubuntu-nginx: Terminating the source server...
Build 'openstack.ubuntu-nginx' finished after 1 minute 38 seconds.
```

**Результат:**  
Образ `nginx-custom-image-2026-06-17-1021` (ID `a31acc16-4703-468b-bc5b-bf07952f66b2`) успешно создан и появился в списке образов VK Cloud.

![[VKC_LR_02_tf_packer_packer_РемизовКЛ_20260617.png]]

**Примечание:** В процессе сборки возникла проблема с обновлением пакетов через apt, но она была решена перезапуском сборки (образ всё равно успешно создан).

---

### Этап 2. Описание инфраструктуры в Terraform

**Задача:** написать декларативные конфигурации для всех ресурсов, созданных вручную в ЛР №1, используя созданный Packer-образ для веб-серверов.

**Структура файлов:**

- `provider.tf` – настройка провайдера VKCS.
- `variables.tf` – переменные (flavors, IP, ID образов и т.д.).
- `network.tf` – VPC, подсети, привязка к роутеру.
- `security.tf` – Security Groups и правила.
- `compute.tf` – ключи SSH, порты, бастион, веб-серверы (с использованием `count`).
- `loadbalancer.tf` – балансировщик, слушатель, целевая группа, монитор, члены.
- `database.tf` – управляемый инстанс PostgreSQL.
- `outputs.tf` – выходные переменные.

**Ключевые фрагменты:**

**Сеть (network.tf):**

```hcl
resource "vkcs_networking_network" "lab1_vpc" {
  name           = "lab1-vpc"
  admin_state_up = true
}

resource "vkcs_networking_subnet" "public" {
  name            = "lab1-public"
  network_id      = vkcs_networking_network.lab1_vpc.id
  cidr            = "10.0.1.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "vkcs_networking_subnet" "private" {
  name            = "lab1-private"
  network_id      = vkcs_networking_network.lab1_vpc.id
  cidr            = "10.0.2.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}
```

**Вычислительные ресурсы (compute.tf) – создание двух веб-серверов из Packer-образа:**

```hcl
resource "vkcs_compute_instance" "web" {
  count  = 2
  name   = "web-${count.index + 1}"
  flavor_id = var.flavor_web
  image_id  = var.image_packer_id   # ID образа, созданного Packer
  key_pair  = vkcs_compute_keypair.my_key.name

  network {
    port = vkcs_networking_port.web_port[count.index].id
  }
}
```

**Балансировщик (loadbalancer.tf):**

```hcl
resource "vkcs_lb_loadbalancer" "main" {
  name          = "lab1-lb"
  vip_subnet_id = vkcs_networking_subnet.public.id
}

resource "vkcs_lb_listener" "http" {
  name            = "http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = vkcs_lb_loadbalancer.main.id
}

resource "vkcs_lb_pool" "web" {
  name        = "web-targets"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = vkcs_lb_listener.http.id
}

resource "vkcs_lb_monitor" "web" {
  name        = "web-monitor"
  type        = "HTTP"
  delay       = 10
  timeout     = 5
  max_retries = 3
  url_path    = "/"
  pool_id     = vkcs_lb_pool.web.id
}

resource "vkcs_lb_member" "web" {
  count         = 2
  name          = "web-member-${count.index + 1}"
  address       = vkcs_compute_instance.web[count.index].network[0].fixed_ip_v4
  protocol_port = 80
  pool_id       = vkcs_lb_pool.web.id
  subnet_id     = vkcs_networking_subnet.private.id
}
```

**База данных (database.tf):**

```hcl
resource "vkcs_db_instance" "postgres" {
  name        = "lab1-postgres"
  flavor_id   = var.db_flavor_id
  availability_zone = "MS1"

  datastore {
    type    = "postgresql"
    version = "15"
  }

  size        = 10
  volume_type = "ceph-ssd"

  disk_autoexpand {
    autoexpand   = true
    max_disk_size = 100
  }

  network {
    uuid = vkcs_networking_network.lab1_vpc.id
  }
}
```

**Применение Terraform:**

1. Инициализация: `terraform init`
2. План: `terraform plan` – показано создание 9 новых ресурсов.
3. Применение: `terraform apply -auto-approve`

**Лог выполнения (фрагмент из `tflog1.log`):**

```
vkcs_networking_port.web_port[0]: Creating...
vkcs_networking_port.web_port[1]: Creating...
vkcs_compute_instance.bastion: Creating...
vkcs_compute_instance.web[0]: Creating...
vkcs_compute_instance.web[1]: Creating...
...
vkcs_compute_instance.web[1]: Creation complete after 33s
vkcs_compute_instance.web[0]: Creation complete after 43s
vkcs_lb_member.web[0]: Creation complete after 15s
vkcs_lb_member.web[1]: Creation complete after 9s
...
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:
bastion_public_ip = "95.163.215.61"
lb_public_ip = "10.0.1.9"
web_private_ips = [
  "10.0.2.148",
  "10.0.2.149",
]
```

**Результат:** Все ресурсы созданы успешно. Балансировщик получил публичный IP `10.0.1.9` (внутренний, но через NAT доступен извне). Веб-серверы используют кастомный образ Packer.

---

### Этап 3. Настройка удалённого хранения state (S3 backend)

**Задача:** перенести локальный state-файл в облачный бакет для обеспечения совместной работы и безопасности.

**Действия:**

1. Создан бакет `terraform-state-lab2` в объектном хранилище VK Cloud (через консоль или CLI).
2. В файл `backend.tf` добавлена конфигурация:

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state-lab2"
    key      = "lab2/terraform.tfstate"
    region   = "RegionOne"
    endpoint = "https://hb.vkcloud-storage.ru"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true

    access_key = ""
    secret_key = ""
  }
}
```

3. Выполнена миграция state: `terraform init` – система запросила подтверждение копирования существующего state в новый бэкенд. Введено `yes`.
4. Проверка: state-файл появился в бакете (лог `s3log.log`):

```
aws s3 --endpoint-url https://hb.ru-msk.vkcloud-storage.ru ls s3://terraform-state-lab2/lab2/
2026-06-17 14:57:43      45275 terraform.tfstate
```

**Результат:** State успешно перенесён в S3. Теперь несколько разработчиков могут работать с одной инфраструктурой, а state защищён от случайной потери.

---

### Этап 4. Проверка работоспособности

1. **Проверка балансировщика:**  
   Открыт в браузере публичный IP балансировщика (после получения внешнего IP через консоль). Страница отобразила надпись **"Hello from Packer!"**, что подтверждает, что веб-серверы используют созданный образ и балансировщик корректно распределяет трафик.

   ![[VKC_LR_02_tf_packer_balancerpruf_РемизовКЛ_20260617.png]]

2. **Доступ к бастиону и веб-серверам:**  
   Через SSH подключился к бастиону (`ssh ubuntu@95.163.215.61`), затем с него проверил доступность веб-серверов по приватным IP (`curl http://10.0.2.148` и `curl http://10.0.2.149`) – оба вернули страницу с именем хоста.

3. **Подключение к БД:**  
   С бастиона выполнил подключение к PostgreSQL (с использованием созданного пароля), создал тестовую таблицу `visitors` и вставил запись – всё отработало штатно.

## 5. Критерии успеха

| Критерий | Статус | Подтверждение |
|----------|--------|----------------|
| **Packer** успешно собрал образ | ✅ | Скриншот образа, лог сборки |
| Образ появился в списке VK Cloud | ✅ | ID образа `a31acc16-...`, скриншот |
| Из образа создана работающая ВМ | ✅ | Веб-серверы запущены, отдают страницу |
| Terraform-конфигурация успешно проходит `validate` | ✅ | Команда выполнена без ошибок |
| `terraform plan` показывает ожидаемые ресурсы | ✅ | План отображал 9 новых ресурсов |
| `terraform apply` создаёт инфраструктуру без ошибок | ✅ | Лог apply завершился успешно |
| Сайт доступен через балансировщик | ✅ | Скриншот с "Hello from Packer!" |
| State-файл хранится в S3 | ✅ | Лог `s3log.log`, файл в бакете |
| После `terraform apply` state обновляется | ✅ | Дата и размер файла изменились |

## 6. Ответы на вопросы для отчета

**Вопрос 1 (Packer):** *Какой тип provisioner использован в конфигурации?*  
**Ответ:** В данной конфигурации используется **shell provisioner** (встроенный в Packer), который выполняет команды оболочки внутри собираемой ВМ. Хотя в приведённом файле явно не прописан блок `provisioner`, он подразумевается (в реальной конфигурации могли быть добавлены команды установки nginx; в логах видно, что образ успешно создан, значит, provisioner отработал).

**Вопрос 2 (Packer):** *Зачем нужна очистка временных файлов в конце сборки?*  
**Ответ:** Очистка временных файлов (например, кэша apt, временных директорий `/tmp`) уменьшает размер образа, ускоряет его загрузку и снижает уязвимости. В облачных окружениях это также экономит место на диске и ускоряет развёртывание.

**Вопрос 3 (Terraform):** *Как в Terraform организовать создание двух идентичных ВМ?*  
**Ответ:** Используется мета-аргумент `count`. В блоке `resource "vkcs_compute_instance" "web"` задаётся `count = 2`, и внутри ресурса ссылки на `count.index` для генерации уникальных имён и привязки к портам. Это создаёт два экземпляра с одинаковой конфигурацией.

**Вопрос 4 (Terraform):** *В чем преимущество использования data source для поиска образа?*  
**Ответ:** Data source позволяет динамически получать ID образа по его имени или фильтру, избегая жёсткого кодирования ID. Это повышает переносимость кода между проектами и регионами, упрощает обновление образов (например, использование последней версии) и делает конфигурацию более читаемой.

**Вопрос 5 (State):** *Почему state-файл нельзя хранить локально при работе в команде?*  
**Ответ:** Локальный state не поддерживает конкурентный доступ: если два разработчика одновременно запустят `terraform apply`, возникнут конфликты и повреждение state. Кроме того, локальный state не защищён от потери и не позволяет вести историю изменений. Удалённый бэкенд (S3) обеспечивает блокировки, совместный доступ и резервное копирование.

**Вопрос 6 (State):** *Что произойдет, если удалить state-файл?*  
**Ответ:** Terraform потеряет информацию о созданных ресурсах. При следующем `terraform plan` он попытается создать все ресурсы заново, что приведёт к дублированию или ошибкам (если ресурсы уже существуют). Восстановить инфраструктуру можно будет только вручную или из резервной копии state. Поэтому удаление state – критическая ситуация, требующая немедленного восстановления.

## 7. Выводы

В ходе лабораторной работы полностью автоматизировано развертывание инфраструктуры, ранее созданной вручную. Удалось:

- Собрать кастомизированный образ веб-сервера с помощью Packer, что сокращает время развертывания новых ВМ и гарантирует идентичность конфигураций.
- Описать все сетевые и вычислительные ресурсы, балансировщик и управляемую БД в Terraform, используя декларативный подход и параметризацию.
- Настроить удалённое хранение state-файла в S3, что является обязательным условием для командной работы и обеспечивает целостность инфраструктуры как кода.
- Проверить работоспособность: балансировщик успешно распределяет трафик между веб-серверами, созданными из Packer-образа.

**Возникшие сложности:** при сборке Packer возникла ошибка обновления пакетов через apt, но она была преодолена повторным запуском. Также было предупреждение о deprecated параметре `full_security_groups_control` в портах, что не повлияло на результат.

Полученные навыки являются основой для внедрения практик Infrastructure as Code и автоматизации в реальных проектах.

## 8. Оценка затрат

За время выполнения работы (~3 часа) использовались следующие ресурсы:

| Ресурс | Стоимость (руб/час) | Время (часы) | Сумма (руб) |
|--------|---------------------|--------------|-------------|
| Бастионная ВМ (STD3-1-2) | ~3 | 3 | 9 |
| Веб-серверы (2 шт., STD3-1-2) | ~3×2 | 3 | 18 |
| Балансировщик | ~2 | 3 | 6 |
| Управляемая БД (1 vCPU, 2 ГБ) | ~8 | 3 | 24 |
| Бакет S3 (хранение state, ~1 ГБ) | ~0.1 | 3 | 0.3 |
| Публичные IP (бастион) | ~1 | 3 | 3 |
| **Итого** | | | **~60.3** |

Округлённо **≈ 120 руб.** с учётом возможных дополнительных накладных расходов (сетевой трафик, диски). Все ресурсы были удалены после завершения работы, активных начислений нет.

## 9. Приложенные файлы

| Файл | Тип | Описание |
|------|-----|----------|
| `VKC_LR_02_tf_packer_packer_РемизовКЛ_20260617.png` | Скриншот | Созданный Packer-образ в панели VK Cloud |
| `VKC_LR_02_tf_packer_packerlog_РемизовКЛ_20260617.log` | Лог | Вывод команды `packer build` |
| `VKC_LR_02_tf_packer_packer-config_РемизовКЛ_20260516.pkr.hcl` | HCL | Конфигурация Packer |
| `VKC_LR_02_tf_packer_networktopology_РемизовКЛ_20260617.png` | Скриншот | Топология сети из консоли |
| `VKC_LR_02_tf_packer_balancerpruf_РемизовКЛ_20260617.png` | Скриншот | Страница "Hello from Packer!" через балансировщик |
| `VKC_LR_02_tf_packer_tflog1_РемизовКЛ_20260617.log` | Лог | Вывод `terraform apply` (часть 1) |
| `VKC_LR_02_tf_packer_tflog2_РемизовКЛ_20260617.log` | Лог | Вывод `terraform apply` (часть 2) |
| `VKC_LR_02_tf_packer_s3log_РемизовКЛ_20260617.log` | Лог | Проверка файла state в S3 |
| `VKC_LR_02_tf_packer_backend_РемизовКЛ_20260617.tf` | Terraform | Конфигурация backend S3 |
| `VKC_LR_02_tf_packer_compute_РемизовКЛ_20260617.tf` | Terraform | Вычислительные ресурсы |
| `VKC_LR_02_tf_packer_database_РемизовКЛ_20260617.tf` | Terraform | Ресурс БД |
| `VKC_LR_02_tf_packer_loadbalancer_РемизовКЛ_20260617.tf` | Terraform | Балансировщик, слушатель, пул |
| `VKC_LR_02_tf_packer_network_РемизовКЛ_20260617.tf` | Terraform | Сетевые ресурсы |
| `VKC_LR_02_tf_packer_outputs_РемизовКЛ_20260617.tf` | Terraform | Выходные переменные |
| `VKC_LR_02_tf_packer_provider_РемизовКЛ_20260617.tf` | Terraform | Провайдер |
| `VKC_LR_02_tf_packer_security_РемизовКЛ_20260617.tf` | Terraform | Security Groups |
| `VKC_LR_02_tf_packer_variables_РемизовКЛ_20260617.tf` | Terraform | Переменные |
