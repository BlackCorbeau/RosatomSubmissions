---
course_code: VKCLOUD-80
artifact_type: ENV
module: M00
task_code: PR00
task_title: Настройка учебной среды
student_fio: Ремизов Кирилл
date: 26.05.2026
source_docs:
  - Д1
  - Д2
  - Д7
  - Д8
attached_files:
  - VKC_ENV_M00_PR00_security_РемизовКЛ_20260526.png
  - VKC_ENV_M00_PR00_terraformcreating1_РемизовКЛ_20260526.png
  - VKC_ENV_M00_PR00_terraformcreating2_РемизовКЛ_20260526.png
  - VKC_ENV_M00_PR00_firstVM_РемизовКЛ_20260526.png
  - VKC_ENV_M00_PR00_connectofirstVM_РемизовКЛ_20260526.png
  - VKC_ENV_M00_PR00_openstackcreating_РемизовКЛ_20260526.png
  - VKC_ENV_M00_PR00_terraformcreatingcheck_РемизовКЛ_20260526.png
status: final
---

# Отчёт по настройке учебной среды

## 1. Что было сделано

- Создан аккаунт VK Cloud (`remizov.kirill2005@yandex.ru`) с проектом `mcs3340419193`. Для аккаунта включена двухфакторная аутентификация.
- Создана первая виртуальная машина через веб-интерфейс VK Cloud.
- Выполнено подключение к ВМ по SSH.
- Создана виртуальная машина с помощью OpenStack CLI.
- Создана виртуальная машина с помощью Terraform.

## 2. Выполненные шаги

### 1. Создание и настройка аккаунта в VK Cloud

1. **Регистрация** – через [страницу регистрации VK Cloud](https://cloud.vk.com/authapp/signup?region_name=RegionOne).
2. **Верификация** – подтверждены адрес электронной почты и номер телефона.
3. **Безопасность** – включена двухфакторная аутентификация.
  ![Общий вид](VKC_ENV_M00_PR00_security_РемизовКЛ_20260526.png)
### 2. Создание первой ВМ через веб-интерфейс

1. Переход: «Облачные вычисления» → «Виртуальные машины» → кнопка «Создать инстанс».
2. Создана ВМ `my-first-vm` со следующими параметрами:
   - ОС: Ubuntu 24.04
   - Тип ВМ: STD3-1-2
   - Зона доступности: PA2
   - Размер диска: 12 ГБ
   - Firewall: все разрешено

![Создание первой ВМ](VKC_ENV_M00_PR00_firstVM_РемизовКЛ_20260526.png)

### 3. Подключение к ВМ по SSH

1. Приватный ключ скачан автоматически при создании ВМ.
2. Выданы права на ключ: `chmod 400`.
3. Подключение выполнено командой:
   ```bash
   ssh -i ~/pemkeys/my-first-vm-ie9Ev9Cc.pem ubuntu@95.163.214.61
   ```

![SSH-подключение](VKC_ENV_M00_PR00_connectofirstVM_РемизовКЛ_20260526.png)

### 4. Создание ВМ с помощью OpenStack CLI

1. Подготовлено виртуальное окружение (файл `shell.nix`).
2. Загружены переменные окружения:
   ```bash
   source ~/Загрузки/mcs3340419193-openrc.sh
   ```
3. Выполнена команда создания ВМ:
   ```bash
   openstack server create \
     --flavor Basic-1-1-10 \
     --image "a4e699d3-a66d-45e5-bb5d-70ea7c8de62d" \
     --network "ec8c610e-6387-447e-83d2-d2c541e88164" \
     --key-name my-first-vm-ie9Ev9Cc \
     cli-created-vm
   ```
4. Проверено, что сервер создан и работает.

![Список ВМ после создания через CLI](VKC_ENV_M00_PR00_openstackcreating_РемизовКЛ_20260526.png)  
![Детали ВМ CLI](VKC_ENV_M00_PR00_openstackcreatinglist_РемизовКЛ_20260526.png)

### 5. Создание ВМ с помощью Terraform

1. Подготовлено виртуальное окружение (файл `shell.nix`).
2. Создан файл `main.tf` по предоставленному шаблону.
3. Изучена документация Terraform после возникновения ошибок.
4. Скачан файл конфигурации Terraform из настроек проекта.
5. Финальная конфигурация `main.tf`:

   ```hcl
   terraform {
     required_providers {
       vkcs = {
         source  = "vk-cs/vkcs"
         version = "~> 0.1"
       }
     }
   }

   provider "vkcs" {
     username   = "<Логин из настроек проекта / Terraform>"
     password   = "<Пароль>"
     project_id = "<ID проекта>"
     region     = "<Регион, например RegionOne>"
     auth_url   = "https://infra.mail.ru:35357/v3/"
   }

   resource "vkcs_compute_keypair" "my_key" {
     name       = "terraform-key"
     public_key = file("~/.ssh/terraform_rsa.pub")
   }

   resource "vkcs_compute_instance" "terraform_vm" {
     name        = "terraform-created-vm"
     flavor_id   = "df3c499a-044f-41d2-8612-d303adc613cc"
     image_name  = "ubuntu-22-202602051629.gite7a38aaf"

     network {
       uuid = "ec8c610e-6387-447e-83d2-d2c541e88164"
     }

     key_pair = vkcs_compute_keypair.my_key.name

     metadata = {
       environment = "dev"
       created_by  = "terraform"
     }
   }

   output "vm_ip" {
     value = vkcs_compute_instance.terraform_vm.access_ip_v4
   }

   output "vm_name" {
     value = vkcs_compute_instance.terraform_vm.name
   }
   ```

6. Выполнены команды:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

![Terraform plan](VKC_ENV_M00_PR00_terraformcreating1_РемизовКЛ_20260526.png)
 ![Terraform plan](VKC_ENV_M00_PR00_terraformcreating2_РемизовКЛ_20260526.png)
![Terraform apply успех](VKC_ENV_M00_PR00_terraformcreatingcheck_РемизовКЛ_20260526.png)

## 3. Доказательства

- Скриншот создания первой ВМ:  
  ![Первая ВМ](VKC_ENV_M00_PR00_firstVM_РемизовКЛ_20260526.png)
- Скриншот SSH-подключения:  
  ![SSH](VKC_ENV_M00_PR00_connectofirstVM_РемизовКЛ_20260526.png)
- ВМ, созданная через OpenStack CLI (список):  
  ![CLI ВМ список](VKC_ENV_M00_PR00_openstackcreating_РемизовКЛ_20260526.png)
- Детали CLI-ВМ:  
  ![CLI ВМ детали](VKC_ENV_M00_PR00_openstackcreatinglist_РемизовКЛ_20260526.png)
- Процесс Terraform `plan`:  

![Terraform plan](VKC_ENV_M00_PR00_terraformcreating1_РемизовКЛ_20260526.png)
 ![Terraform plan](VKC_ENV_M00_PR00_terraformcreating2_РемизовКЛ_20260526.png)
- Результат `terraform apply`:  
  ![Terraform apply](VKC_ENV_M00_PR00_terraformcreatingcheck_РемизовКЛ_20260526.png)

## 4. Проверка готовности

- [x] Вход в аккаунт выполнен (учётная запись `remizov.kirill2005@yandex.ru`, проект `mcs3340419193`).
- [x] Двухфакторная аутентификация включена.
- [x] SSH-ключ создан (использован ключ `my-first-vm-ie9Ev9Cc.pem` для ручного доступа и ключ `terraform-key` для Terraform).
- [x] Рабочая папка создана (присутствуют `shell.nix`, `main.tf`, `openrc.sh` и другие файлы конфигурации).

## 5. Замечания и риски

| № | Замечание / риск | Вероятность | Влияние | Меры предотвращения / комментарий |
|---|------------------|-------------|---------|------------------------------------|
| 1 | При использовании Terraform возникли ошибки из-за неверного синтаксиса или версии провайдера | Средняя | Высокое | Изучена документация, конфигурация приведена к рабочему виду. В будущем использовать актуальные примеры от VK Cloud. |
| 2 | Открытый SSH-ключ `terraform_rsa.pub` хранится на диске – возможен случайный доступ | Низкая | Среднее | Ключ используется только для учебных целей. Рекомендуется не публиковать его в открытых репозиториях. |
| 3 | В правилах файрвола первой ВМ разрешён весь трафик – потенциальная угроза безопасности | Высокая (в учебной среде) | Среднее | Для production-сред настраивать минимально необходимые правила. В учебном проекте допустимо. |
| 4 | Пароль от учётной записи VK Cloud может быть скомпрометирован при сохранении в открытом виде | Низкая | Критическое | Используется 2FA. Пароль не хранится в коде, передаётся через переменные окружения. |
| 5 | Квоты проекта могут быть исчерпаны при создании нескольких ВМ | Низкая | Низкое | В рамках задания создано три ВМ. При необходимости можно удалять неиспользуемые экземпляры. |

## 6. Вывод

Учебная среда VK Cloud полностью настроена. Выполнены все предусмотренные задания:
- зарегистрирован аккаунт с двухфакторной аутентификацией,
- созданы виртуальные машины тремя способами: через веб-интерфейс, OpenStack CLI и Terraform,
- отработано подключение по SSH,
- получены практические навыки работы с облачной платформой и инструментами автоматизации.

Все действия подтверждены скриншотами. Система готова к выполнению следующих лабораторных работ модуля `M00`.
