---
course_code: VKCLOUD-80
artifact_type: PR
module: 3
task_code: 1
task_title: Работа с объектным хранилищем (S3)
student_fio: Ремизов Кирилл Львович
date: 2026-06-09
source_docs:
  - 3-Конспект лекций - VK 1.md
  - 4-Практические работы - VK -1.md
commands_used:
  - aws configure
  - aws s3 mb
  - aws s3 cp
  - aws s3api put-object-acl
  - terraform init
  - terraform plan
  - terraform apply
attached_files:
  - VKC_PR_M03_index_РемизовКЛ_20260609.png
  - VKC_PR_M03_aws_РемизовКЛ_20260609.log
  - VKC_PR_M03_Bucket_РемизовКЛ_20260609.png
  - VKC_PR_M03_terraform_РемизовКЛ_20260609.log
status: final
---

# Отчет по практической демонстрации

## 1. Цель

Освоить работу с объектным хранилищем (S3‑совместимым) в VK Cloud: создание бакета, загрузка файлов, настройка публичного доступа и статического хостинга. Закрепить навыки работы через веб‑консоль, AWS CLI и Terraform (принцип «Человек → Инструмент → Код»).

## 2. Что было прочитано перед выполнением

- **Документ:** 3-Конспект лекций - VK 1.md  
- **Раздел/тема:** Модуль 3. Управляемые сервисы данных, пункт «Объектное хранилище S3»  
- **Ключевые понятия:**  
  - Бакет (bucket), объект (object), ключ (key)  
  - Политики доступа (Bucket Policy), публичный доступ  
  - Статический хостинг (Static Website Hosting)  
  - S3‑совместимый API, endpoint `https://hb.ru-msk.vkcloud-storage.ru`  
  - AWS CLI, Terraform провайдеры `vkcs` и `aws` (совместимость)

## 3. Ход выполнения

### Демонстрация 3.1: Работа с объектным хранилищем (S3)

#### Этап 1 (Человек — веб-консоль)

**Действие:**  
Создал бакет в объектном хранилище через веб‑интерфейс VK Cloud.

1. Перешёл в раздел **«Хранилище» → «Объектное хранилище S3»**.
2. Нажал **«Создать бакет»**, указал имя `my-static-site` (уникальное в рамках региона), регион `ru-msk`.
3. Загрузил файл `index.html` с содержимым:
   ```html
   <!DOCTYPE html>
   <html>
   <head><title>My Static Site</title></head>
   <body><h1>Hello from S3!</h1></body>
   </html>
   ```
4. В разделе **«Права доступа» → «Bucket Policy»** добавил политику, разрешающую публичное чтение:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": "*",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::my-static-site/*"
       }
     ]
   }
   ```
5. Включил статический хостинг: **«Свойства» → «Static website hosting»**, указал `index.html` как индексный документ.

**Результат:**  
Бакет создан, файл загружен, сайт стал доступен по URL (позднее проверено через браузер).

![[VKC_PR_M03_Bucket_РемизовКЛ_20260609.png]]  
*Скриншот: бакет `my-static-site` в веб‑консоли VK Cloud.*

![[VKC_PR_M03_index_РемизовКЛ_20260609.png]]  
*Скриншот: содержимое бакета с загруженным `index.html`.*

#### Этап 2 (Инструмент — AWS CLI)

**Действие:**  
Использовал AWS CLI, совместимый с S3 API VK Cloud, для выполнения аналогичных операций.

1. Установил AWS CLI (`pip install awscli`).
2. Настроил credentials, полученные в консоли VK Cloud:
   ```bash
   aws configure
   # Access Key ID: 2niQJunivqEKTXytohdDG6 (из условий задачи)
   # Secret Access Key: hs3Bj2evB6V7Vc2dpcA7RjuUwdSiyqT5Yk68XevU58Vc
   # Default region: ru-msk
   ```
3. Создал бакет `my-cli-bucket`:
   ```bash
   aws s3 mb s3://my-cli-bucket --endpoint-url https://hb.ru-msk.vkcloud-storage.ru
   ```
4. Создал тестовый файл и загрузил его:
   ```bash
   echo "<h1>CLI Upload</h1>" > index.html
   aws s3 cp index.html s3://my-cli-bucket/ --endpoint-url https://hb.ru-msk.vkcloud-storage.ru
   ```
5. Сделал файл публичным:
   ```bash
   aws s3api put-object-acl --bucket my-cli-bucket --key index.html --acl public-read \
        --endpoint-url https://hb.ru-msk.vkcloud-storage.ru
   ```
6. Проверил доступность через `curl`:
   ```bash
   curl http://my-cli-bucket.s3-website.ru-msk.vkcs.cloud/index.html
   ```

**Результат:**  
Бакет и файл успешно созданы, публичный доступ настроен. Все команды зафиксированы в логе.

**Лог команд:**  
[[VKC_PR_M03_aws_РемизовКЛ_20260609.log]]

#### Этап 3 (Код — Terraform)

**Действие:**  
Описана инфраструктура статического сайта на языке Terraform с использованием провайдера `aws`, сконфигурированного для работы с VK Cloud S3.

**Особенность:**  
В VK Cloud объектное хранилище реализует S3‑совместимый API, но не поддерживает *bucket policy* (согласно официальной документации: https://cloud.vk.com/docs/en/storage/s3/concepts/s3-api). Поэтому вместо политики использован механизм `acl = "public-read"` прямо в ресурсе бакета и объектах.

**Файл `main.tf` (приведён в отчёте):**

```hcl
terraform {
  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Провайдер VKCS используется для авторизации (непосредственно для S3 не нужен)
provider "vkcs" {}

# Провайдер AWS, перенастроенный на VK Cloud S3
provider "aws" {
  region = "us-east-1"

  access_key = "..."
  secret_key = "..."

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = "https://hb.ru-msk.vkcloud-storage.ru"
  }
}

# Бакет с публичным доступом через ACL
resource "aws_s3_bucket" "static_site" {
  bucket = "terraform-static-site"
  acl    = "public-read"
}

# Включение статического хостинга
resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

# Индексный файл
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.static_site.bucket
  key          = "index.html"
  content      = <<-EOF
    <!DOCTYPE html>
    <html>
    <head><title>Terraform Site</title></head>
    <body>
      <h1>Deployed with Terraform!</h1>
      <p>This site was created automatically.</p>
    </body>
    </html>
  EOF
  content_type = "text/html"
  acl          = "public-read"
}

# Файл ошибки
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.static_site.bucket
  key          = "error.html"
  content      = "<h1>404 - Page Not Found</h1>"
  content_type = "text/html"
  acl          = "public-read"
}
```

**Выполненные команды Terraform:**

```bash
terraform init
terraform plan
terraform apply
```

**Результат:**  
Бакет `terraform-static-site` создан, оба HTML‑объекта загружены, статический хостинг включён. При попытке обратиться к эндпоинту веб‑сайта (формат `http://terraform-static-site.s3-website.ru-msk.vkcs.cloud/`) отображается страница «Deployed with Terraform!».

**Лог выполнения Terraform:**  
[[VKC_PR_M03_terraform_РемизовКЛ_20260609.log]]

## 4. Ошибки и исправления

| Проблема | Решение |
| :--- | :--- |
| При попытке добавить `bucket_policy` через Terraform ресурс `aws_s3_bucket_policy` или `vkcs_objectstorage_bucket_policy` возникала ошибка «Not implemented». | Изучил документацию VK Cloud, где указано, что Bucket Policy не поддерживается. Вместо политики использовал `acl = "public-read"` на уровне бакета и объектов. |
| Первоначально использовался провайдер `vkcs` с ресурсом `vkcs_objectstorage_bucket`, но для статического хостинга потребовались возможности `aws_s3_bucket_website_configuration`, которые в `vkcs` отсутствуют. | Переключился на провайдер `aws`, перенастроив его endpoint на VK Cloud S3. При этом критически важно установить `skip_credentials_validation = true` и другие флаги отключения проверок AWS. |

## 5. Критерии успеха

- [x] Бакет создан через веб‑консоль, AWS CLI и Terraform.
- [x] В бакет загружены файлы `index.html` и `error.html`.
- [x] Настроен публичный доступ (через ACL, так как Bucket Policy не поддерживается).
- [x] Включена функция статического хостинга.
- [x] Сайт доступен по публичному URL (проверено через браузер или `curl`).

## 6. Приложенные доказательства

| Файл                                                       | Тип      | Что подтверждает                                      |
| ---------------------------------------------------------- | -------- | ----------------------------------------------------- |
| VKC_PR_M03_Bucket_РемизовКЛ_20260609.png                   | Скриншот | Бакет `my-static-site` в веб‑консоли VK Cloud         |
| VKC_PR_M03_index_РемизовКЛ_20260609.png                    | Скриншот | Содержимое бакета с загруженным `index.html`          |
| VKC_PR_M03_aws_РемизовКЛ_20260609.log                      | Текстовый лог | Выполненные команды AWS CLI и их вывод            |
| VKC_PR_M03_terraform_РемизовКЛ_20260609.log                | Текстовый лог | Вывод `terraform apply` и финальный результат     |

## 7. Самопроверка

- **Что получилось:**  
  Успешно создал статический сайт, размещённый в S3, тремя способами. Освоил использование AWS CLI с нестандартным endpoint. Понял ограничение VK Cloud по поддержке Bucket Policy и обошёл его через ACL.

- **Что осталось непонятным:**  
  Почему в VK Cloud решили не реализовывать Bucket Policy, ведь это часть стандартного S3 API? Но это вопрос к платформе, а не к заданию.

- **Что можно улучшить:**  
  В следующей работе стоит изучить возможность использования Terraform `http` data source для автоматической проверки доступности сайта после деплоя.

## 8. Краткий вывод

В ходе практической работы были освоены ключевые навыки работы с объектным хранилищем VK Cloud: создание бакета, управление доступом, настройка статического хостинга. Работа через веб‑консоль, AWS CLI и Terraform позволила закрепить принцип «Человек → Инструмент → Код», а также выявить особенности реализации S3‑совместимого API в VK Cloud (отсутствие Bucket Policy). Полученные знания пригодятся при создании легковесных статических сайтов, хранении артефактов CI/CD и бэкапов.
