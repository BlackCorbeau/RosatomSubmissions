---
course_code: VKCLOUD-80
artifact_type: PR
module: 3
task_code: 2
task_title: Создание управляемой базы данных PostgreSQL
student_fio: Ремизов Кирилл Львович
date: 2026-06-10
source_docs:
  - 3-Конспект лекций - VK 1.md
  - 4-Практические работы - VK -1.md
commands_used:
  - psql
  - openstack database instance list (не удалось)
  - terraform init/plan/apply
attached_files:
  - VKC_PR_M03_CreatedDBShow_РемизовКЛ_20260609.png
  - VKC_PR_M03_DBLog_РемизовКЛ_20260610.log
  - VKC_PR_M03_DBopenStack_РемизовКЛ_20260610.log
  - VKC_PR_M03_DBTerraform_РемизовКЛ_20260610.log
status: final
---

# Отчет по практической демонстрации

## 1. Цель

Освоить создание и использование управляемого инстанса PostgreSQL (DBaaS) в VK Cloud.  
Научиться выполнять операции через веб‑консоль, OpenStack CLI (по возможности) и Terraform, а также подключаться к БД, создавать таблицы и работать с данными.  
Закрепить принцип «Человек → Инструмент → Код» и понимание преимуществ DBaaS.

## 2. Что было прочитано перед выполнением

- **Документ:** 3-Конспект лекций - VK 1.md  
- **Раздел/тема:** Модуль 3 «Управляемые сервисы данных», тема 3.2 «Управляемые базы данных (DBaaS)»  
- **Ключевые понятия:**  
  - DBaaS, автоматическое резервное копирование (PITR)  
  - Реляционные СУБД: PostgreSQL, MySQL  
  - Сеть для БД (приватные подсети), бастионный хост  
  - Параметры подключения: хост, порт, пользователь, пароль  
  - Terraform‑ресурсы: `vkcs_db_instance`, `vkcs_db_database`, `vkcs_db_user`, `random_password`

## 3. Ход выполнения

### Демонстрация 3.2: Создание управляемой базы данных PostgreSQL

#### Этап 1 (Человек — веб‑консоль)

**Действие:**  
Создал инстанс PostgreSQL через веб‑интерфейс VK Cloud, настроил доступ и выполнил SQL‑запросы.

1. Перешёл в раздел **«Базы данных» → «PostgreSQL»**, нажал **«Создать кластер»**.
2. Задал параметры:
   - Имя: `my-postgres`
   - Конфигурация: `1 vCPU, 2 GB RAM` (минимальная)
   - Версия: `15`
   - Размер диска: `10 GB`
   - Сеть: приватная подсеть (ранее созданная в рамках VPC)
   - Пользователь: `app_user`, пароль установлен
   - База данных: `app_db`
3. Дождался создания инстанса (3–5 минут).
4. Для подключения использовал тестовую ВМ, находящуюся в той же приватной сети (без публичного IP). На ВМ установил `postgresql-client`:
   ```bash
   sudo apt update && sudo apt install postgresql-client -y
   ```
5. Подключился к БД:
   ```bash
   psql -h 192.168.199.129 -U app_user -d app_db
   ```
6. Выполнил SQL‑скрипт (создание таблицы `users`, вставка данных, выборка):
   ```sql
   CREATE TABLE users (
       id SERIAL PRIMARY KEY,
       name VARCHAR(100),
       email VARCHAR(100) UNIQUE,
       created_at TIMESTAMP DEFAULT NOW()
   );
   INSERT INTO users (name, email) VALUES
       ('Alice', 'alice@example.com'),
       ('Bob', 'bob@example.com');
   SELECT * FROM users;
   ```

**Результат:**  
Таблица создана, данные вставлены и успешно прочитаны. Подтверждение в логе подключения.

![[VKC_PR_M03_CreatedDBShow_РемизовКЛ_20260609.png]]  
*Скриншот: созданный инстанс `my-postgres` в веб‑консоли VK Cloud.*

**Лог подключения и SQL‑команд:**  
[[VKC_PR_M03_DBLog_РемизовКЛ_20260610.log]]

---

#### Этап 2 (Инструмент — OpenStack CLI)

**Действие:**  
Попытался использовать OpenStack CLI для управления инстансом БД, как описано в сценарии практической работы.

**Выполненные команды:**

```bash
openstack database instance list
openstack database instance show my-postgres
openstack database instance show my-postgres -c hosts -c datastore
```

**Результат:**  
Команды завершились с ошибкой:
```
openstack: 'database instance list' is not an openstack command. See 'openstack --help'.
```

**Причина:**  
Стандартный пакет `python-openstackclient` не включает модуль `database`. Для управления базами данных через CLI в VK Cloud требуется отдельный плагин (например, `openstack-database` или использование `trove`), который может отсутствовать в базовой установке. Кроме того, в используемой версии OpenStack API провайдера может быть ограничена поддержка команд CLI для DBaaS.

**Вывод:**  
Автоматизировать управление DBaaS через OpenStack CLI напрямую из коробки не удалось. Этот этап помечен как **невыполнимый в рамках данной лабораторной среды**. В реальном проекте следовало бы изучить доступные плагины или применять альтернативные инструменты (API, Terraform).

**Лог неудачных попыток:**  
[[VKC_PR_M03_DBopenStack_РемизовКЛ_20260610.log]]

---

#### Этап 3 (Код — Terraform)

**Действие:**  
Описана инфраструктура для управляемой БД на языке Terraform с использованием провайдера `vkcs`. В конфигурацию включены создание сети (подсеть, подключение к существующему роутеру), инстанса PostgreSQL, базы данных и пользователя с автоматически сгенерированным паролем.

**Файл `main.tf` (приведён в шаблоне отчёта):**

```hcl
terraform {
  required_providers {
    vkcs = { source = "vk-cs/vkcs" }
    random = { source = "hashicorp/random" }
  }
}

provider "vkcs" {}

data "vkcs_networking_router" "main" {
  name = "router_5390"
}

resource "vkcs_networking_network" "main" {
  name           = "postgres-network"
  admin_state_up = true
}

resource "vkcs_networking_subnet" "main" {
  name       = "postgres-subnet"
  network_id = vkcs_networking_network.main.id
  cidr       = "192.168.199.0/24"
}

resource "vkcs_networking_router_interface" "main" {
  router_id = data.vkcs_networking_router.main.id
  subnet_id = vkcs_networking_subnet.main.id
}

resource "vkcs_db_instance" "postgres" {
  name                = "terraform-postgres"
  flavor_id           = "2df6e3ec-5939-4d28-a818-89558ff1b7ab"
  volume_type         = "ceph-ssd"
  size                = 10
  availability_zone   = "MS1"
  floating_ip_enabled = true
  datastore {
    type    = "postgresql"
    version = "15"
  }
  network {
    uuid = vkcs_networking_network.main.id
  }
}

resource "random_password" "db_password" {
  length      = 16
  special     = true
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

resource "vkcs_db_database" "app_db" {
  name    = "app_db"
  dbms_id = vkcs_db_instance.postgres.id
}

resource "vkcs_db_user" "app_user" {
  name      = "app_user"
  password  = random_password.db_password.result
  dbms_id   = vkcs_db_instance.postgres.id
  databases = [vkcs_db_database.app_db.name]
}

resource "local_file" "db_password" {
  content  = "Database password: ${random_password.db_password.result}"
  filename = "${path.module}/db_password.txt"
}

output "db_host" {
  value = vkcs_db_instance.postgres.hostname
}
output "db_port" { value = 5432 }
output "db_name" { value = vkcs_db_database.app_db.name }
output "db_user" { value = vkcs_db_user.app_user.name }
```

**Выполненные команды Terraform:**

```bash
terraform init
terraform plan
terraform apply -auto-approve   # после успешного plan
```

**Проблема при первом apply:**  
Терраформ выдал ошибку:

```
Error: error creating vkcs_db_instance: Bad request ... "The network must be routable"
```

**Причина:**  
Созданная сеть `postgres-network` не была связана с роутером, имеющим доступ к внешней сети (или не была правильно маршрутизирована). Для управляемой БД нужна сеть, которая может взаимодействовать с другими ресурсами проекта.

**Решение:**  
Добавлен блок `vkcs_networking_router_interface`, который привязывает созданную подсеть к существующему роутеру (`router_5390`). После этого повторный `apply` успешно создал инстанс БД, базу и пользователя.

**Результат:**  
- Инстанс `terraform-postgres` создан (2 мин 39 сек).
- База данных `app_db` и пользователь `app_user` добавлены.
- Пароль сохранён в локальный файл `db_password.txt`.
- Выводы Terraform содержат хост, порт, имя БД и пользователя.

**Лог успешного Terraform‑применения:**  
[[VKC_PR_M03_DBTerraform_РемизовКЛ_20260610.log]]

---

## 4. Ошибки и исправления

| Проблема | Решение |
| :--- | :--- |
| **OpenStack CLI:** команды `openstack database instance ...` отсутствуют. | В текущей установке `python-openstackclient` нет поддержки модуля `database`. Альтернатива – использовать веб‑консоль, Terraform или прямой API. В отчёте этот факт задокументирован как ограничение среды выполнения. |
| **Terraform:** ошибка `The network must be routable` при создании `vkcs_db_instance`. | Созданная сеть не была связана с маршрутизатором. Добавлен ресурс `vkcs_networking_router_interface`, который привязывает подсеть к существующему роутеру (`router_5390`). Это обеспечило маршрутизацию и устранило ошибку. |

## 5. Критерии успеха

- [x] Инстанс управляемой БД PostgreSQL создан через веб‑консоль.
- [x] Подключение к БД выполнено с тестовой ВМ, расположенной в той же сети.
- [x] В БД создана таблица `users`, вставлены тестовые строки, выполнен `SELECT`.
- [x] Terraform‑конфигурация создала инстанс БД, базу и пользователя; пароль сохранён в файл.
- [x] В отчёте описан неудачный опыт использования OpenStack CLI для DBaaS.

## 6. Приложенные доказательства

| Файл                                                       | Тип           | Что подтверждает                                      |
| ---------------------------------------------------------- | ------------- | ----------------------------------------------------- |
| VKC_PR_M03_CreatedDBShow_РемизовКЛ_20260609.png            | Скриншот      | Инстанс `my-postgres` в веб‑консоли VK Cloud          |
| VKC_PR_M03_DBLog_РемизовКЛ_20260610.log                    | Текстовый лог | Подключение `psql`, создание таблицы, вставка данных  |
| VKC_PR_M03_DBopenStack_РемизовКЛ_20260610.log              | Текстовый лог | Неудачные попытки команд OpenStack CLI                |
| VKC_PR_M03_DBTerraform_РемизовКЛ_20260610.log              | Текстовый лог | Успешное применение Terraform (после исправления сети)|

## 7. Самопроверка

- **Что получилось:**  
  Успешно создал управляемую БД через консоль и Terraform. Подключился из ВМ в приватной сети, выполнил SQL‑запросы. Понял, что для Terraform критически важно корректно настроить сеть и маршрутизацию. Освоил ресурсы `vkcs_db_*`.

- **Что осталось непонятным:**  
  Почему в стандартном OpenStack CLI отсутствует поддержка DBaaS. Возможно, требуется установка дополнительного пакета `openstack-trove`. В рабочем проекте этот вопрос требует дополнительного изучения.

- **Что можно улучшить:**  
  В следующей работе стоит попробовать подключить Terraform remote state (например, в S3) и добавить проверку доступности БД с помощью модуля `terraform‑validator`.

## 8. Краткий вывод

В ходе практической работы закреплены навыки создания управляемой базы данных PostgreSQL в VK Cloud тремя способами (консоль, попытка CLI, Terraform). Выявлено, что OpenStack CLI не предоставляет готовых команд для работы с DBaaS — это ограничение, которое следует учитывать при выборе инструментов автоматизации. Terraform, напротив, показал свою эффективность: один конфигурационный файл позволил развернуть сеть, инстанс БД, пользователя и базу данных. Полученные знания пригодятся при проектировании отказоустойчивых приложений, использующих облачные базы данных.

**Ключевой вывод:**  
Для воспроизводимого и контролируемого управления DBaaS в VK Cloud предпочтительнее использовать **Terraform** (или аналогичные инструменты IaC) вместо ручных действий или CLI с неполной поддержкой.
