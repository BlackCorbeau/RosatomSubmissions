---
course_code: VKCLOUD-80
artifact_type: LR
lab_code: 4
lab_title: CI/CD и GitOps
student_fio: Ремизов Кирилл Львович
date: 2026-06-19
source_docs:
  - 5-Задания для лабораторных работ -VK-1.md
  - 3-Конспект лекций - VK 1.md
attached_files:
  - VKC_LR_04_cicd_gitops_main_РемизовКЛ_20260619.tf
  - VKC_LR_04_cicd_gitops_variables_РемизовКЛ_20260619.tf
  - VKC_LR_04_cicd_gitops_outputs_РемизовКЛ_20260619.tf
  - VKC_LR_04_cicd_gitops_backend_РемизовКЛ_20260619.tf
  - VKC_LR_04_cicd_gitops_deployment_РемизовКЛ_20260619.yaml
  - VKC_LR_04_cicd_gitops_service_РемизовКЛ_20260619.yaml
  - VKC_LR_04_cicd_gitops_configmap_РемизовКЛ_20260619.yaml
  - VKC_LR_04_cicd_gitops_kustomization_РемизовКЛ_20260619.yaml
  - VKC_LR_04_cicd_gitops_log_РемизовКЛ_20260619.log
  - VKC_LR_04_cicd_gitops_AgroCDsettings_РемизовКЛ_20260619.png
  - VKC_LR_04_cicd_gitops_sync_РемизовКЛ_20260619.png
  - VKC_LR_04_cicd_gitops_SucsessfulSync_РемизовКЛ_20260619.png
  - VKC_LR_04_cicd_gitops_networktopology_РемизовКЛ_20260619.png
  - VKC_LR_04_cicd_gitops_k8s_РемизовКЛ_20260619.png
  - VKC_LR_04_cicd_gitops_s3_РемизовКЛ_20260619.png
  - VKC_LR_04_cicd_gitops_app-config_РемизовКЛ_20260619.png
estimated_cost_rub: 80
status: final
---

# Отчет по лабораторной работе №4: CI/CD и GitOps

## Цель работы

Настроить CI/CD пайплайн для автоматического развертывания инфраструктуры и приложения, освоить GitOps подход с использованием **ArgoCD**. Основные задачи:
- Развернуть инфраструктуру (VPC, веб-серверы, балансировщик) с помощью **Terraform**, используя удаленное состояние в S3.
- Создать кластер **Kubernetes** и установить **ArgoCD**.
- Подготовить Git-репозиторий с манифестами приложения (Deployment, Service, ConfigMap) и настроить автоматическую синхронизацию через ArgoCD.
- Интегрировать Terraform и Kubernetes: передать IP-адрес балансировщика в ConfigMap приложения.

---

## Используемые ресурсы

| Ресурс | Тип | Параметры | Назначение |
|--------|-----|-----------|-------------|
| VPC `lab4-network` | Virtual Private Cloud | sdn: "sprut" | Изолированная сеть для всех ресурсов |
| Публичная подсеть `lab4-public-subnet` | Subnet | CIDR: 192.168.1.0/24 | Размещение балансировщика и внешних ресурсов |
| Приватная подсеть `lab4-private-subnet` | Subnet | CIDR: 192.168.2.0/24 | Размещение веб-серверов и внутренних ресурсов |
| Веб-серверы `lab4-web-1`, `lab4-web-2` | ВМ (Ubuntu 20.04) | Флейвор `Basic-1-1-10`, приватные IP 192.168.2.10/11 | Обработка HTTP-запросов, работающие за балансировщиком |
| Балансировщик `lab4-lb` | Application Load Balancer | L7, публичный IP 95.163.215.1 | Распределение трафика между веб-серверами |
| Бакет S3 `tf-state-lab4` | Object Storage | Регион ru-msk | Хранение state-файла Terraform (backend) |
| Кластер Kubernetes `lab-4` | Managed K8s | 1 мастер-узел, 1 узел (STD3-1-2) | Среда выполнения контейнеризированного приложения |
| ArgoCD | Kubernetes приложение | Установлено в namespace `argocd` | GitOps-инструмент для синхронизации состояния кластера с Git-репозиторием |

---

## Схема архитектуры

Архитектура включает две основные части:

1. **Инфраструктура (Terraform):**
   - VPC с двумя подсетями (публичная и приватная).
   - Два веб-сервера в приватной подсети с установленным nginx.
   - Балансировщик нагрузки в публичной подсети, распределяющий трафик между веб-серверами.
   - Бакет S3 для удаленного хранения state-файла.

2. **Приложение и GitOps (Kubernetes + ArgoCD):**
   - Кластер Kubernetes, развернутый отдельно.
   - ArgoCD, установленный в кластер и подключенный к Git-репозиторию с манифестами.
   - В репозитории находятся:
     - `deployment.yaml` – развертывание nginx (2 реплики).
     - `service.yaml` – сервис типа LoadBalancer для доступа к приложению.
     - `configmap.yaml` – содержит IP-адрес балансировщика инфраструктуры.
     - `kustomization.yaml` – для управления ресурсами.
   - ArgoCD автоматически синхронизирует состояние кластера с репозиторием.

![[VKC_LR_04_cicd_gitops_networktopology_РемизовКЛ_20260619.png]]

---

## Ход выполнения

### Шаг 1. Развертывание инфраструктуры с помощью Terraform

**Задача:** Автоматизировать создание сети, веб-серверов и балансировщика с использованием Terraform, настроить удаленное состояние в S3.

**Используемые инструменты:** Terraform (провайдер VKCS), OpenStack CLI, S3.

**Ключевые изменения в конфигурации Terraform:**

1. **Настройка бэкенда S3** (`backend.tf`):
   ```hcl
   terraform {
     backend "s3" {
       bucket   = "tf-state-lab4"
       key      = "lab4/terraform.tfstate"
       region   = "ru-msk"
       endpoint = "https://hb.ru-msk.vkcloud-storage.ru"
       skip_region_validation      = true
       skip_credentials_validation = true
       skip_metadata_api_check     = true
     }
   }
   ```

2. **Создание сети и подсетей** – аналогично предыдущим работам.

3. **Создание двух веб-серверов** через `count`:
   ```hcl
   resource "vkcs_compute_instance" "web" {
     count = 2
     name               = "${var.project_name}-web-${count.index + 1}"
     flavor_id          = data.vkcs_compute_flavor.web.id
     # ...
     network {
       fixed_ip_v4 = cidrhost(var.private_subnet_cidr, count.index + 10)
     }
     user_data = <<-EOF
       #!/bin/bash
       apt update
       apt install -y nginx
       echo "<h1>Web Server $(hostname)</h1>" > /var/www/html/index.html
       systemctl enable nginx
       systemctl start nginx
     EOF
   }
   ```

4. **Балансировщик нагрузки** и его настройка (слушатель, пул, монитор, члены).

5. **Выходные переменные** (`outputs.tf`):
   ```hcl
   output "load_balancer_ip" {
     value = vkcs_networking_floatingip.lb.address
   }
   ```

**Применение Terraform:**

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

В результате был получен публичный IP балансировщика – `95.163.215.1`. State-файл успешно сохранился в бакете `tf-state-lab4` (папка `lab4/`).

![[VKC_LR_04_cicd_gitops_s3_РемизовКЛ_20260619.png]]

---

### Шаг 2. Создание кластера Kubernetes

**Задача:** Создать управляемый кластер Kubernetes для размещения приложения.

**Действия:**
- В консоли VK Cloud создан кластер с именем `lab-4` (1 мастер-узел, 1 рабочий узел, конфигурация STD3-1-2).
- Получен конфигурационный файл `kubeconfig` для доступа к кластеру.

![[VKC_LR_04_cicd_gitops_k8s_РемизовКЛ_20260619.png]]

---

### Шаг 3. Установка ArgoCD

**Задача:** Развернуть ArgoCD в кластере Kubernetes и получить доступ к UI.

**Действия:**

1. Создание namespace `argocd`:
   ```bash
   kubectl create namespace argocd
   ```

2. Установка ArgoCD из официального манифеста:
   ```bash
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
   ```

3. Проверка запуска подов:
   ```bash
   kubectl get pods -n argocd
   ```
   Все поды перешли в состояние `Running`.

4. Получение пароля администратора:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```
   Пароль: `weSuC1mk3y7zG3Hp` (сгенерирован автоматически).

5. Настройка доступа к ArgoCD через port-forward:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   После этого интерфейс ArgoCD стал доступен по адресу `https://localhost:8080`.

![[VKC_LR_04_cicd_gitops_AgroCDsettings_РемизовКЛ_20260619.png]]

---

### Шаг 4. Подготовка манифестов приложения

**Задача:** Создать Git-репозиторий с манифестами Kubernetes для развертывания приложения (nginx) и настроить Kustomize.

**Состав манифестов:**

**deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: web-app
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.6
        ports:
        - containerPort: 80
```

**service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: web-app
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
```

**configmap.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: web-app
data:
  LB_IP: "95.163.215.1"
```

**kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
- configmap.yaml
```

---

### Шаг 5. Настройка приложения в ArgoCD и синхронизация

**Задача:** Создать Application в ArgoCD, указав репозиторий с манифестами, и выполнить синхронизацию.

**Действия:**

1. В UI ArgoCD добавлен новый Application:
   - **Имя:** `lab4`
   - **Проект:** `default`
   - **Репозиторий:** `https://github.com/BlackCorbear/lab4`
   - **Путь:** `kubernetes/`
   - **Целевая ревизия:** `main`
   - **Кластер:** `in-cluster`
   - **Namespace:** `web-app`

2. Включена автоматическая синхронизация (`Auto-Sync`) с опциями `Prune Resources` и `SelfHeal`.

3. После создания Application ArgoCD показал состояние **OutOfSync**. Нажата кнопка **Sync**.

![[VKC_LR_04_cicd_gitops_sync_РемизовКЛ_20260619.png]]

4. Синхронизация прошла успешно – все ресурсы созданы, Application перешло в состояние **Synced** и **Healthy**.

![[VKC_LR_04_cicd_gitops_SucsessfulSync_РемизовКЛ_20260619.png]]

---

### Шаг 6. Проверка работы приложения и ConfigMap

**Задача:** Убедиться, что приложение развернуто, сервис получил внешний IP, а ConfigMap содержит корректный IP балансировщика.

**Проверка ConfigMap:**
```bash
kubectl get configmap app-config -n web-app -o yaml
```
Вывод:
```yaml
apiVersion: v1
data:
  LB_IP: 95.163.215.1
kind: ConfigMap
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: lab4:/ConfigMap:web-app/app-config
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"LB_IP":"95.163.215.1"},"kind":"ConfigMap",...}
  name: app-config
  namespace: web-app
  ...
```

Значение `LB_IP` соответствует IP балансировщика из Terraform, что подтверждает успешную интеграцию.

![[VKC_LR_04_cicd_gitops_app-config_РемизовКЛ_20260619.png]]

**Доступность приложения:**
- Сервис типа LoadBalancer получил внешний IP.
- При обращении к этому IP открывается страница nginx.

---

## Критерии успеха

| Критерий | Статус | Подтверждение |
|----------|--------|----------------|
| Инфраструктура развернута через Terraform с S3 backend | ✅ | State-файл в бакете, скриншот бакета |
| Кластер Kubernetes создан | ✅ | Скриншот кластера |
| ArgoCD установлен и доступен | ✅ | Лог установки, скриншот ArgoCD Settings |
| Манифесты приложения подготовлены | ✅ | Файлы приложены, скриншот ConfigMap |
| Application в ArgoCD синхронизирован | ✅ | Скриншот Successful Sync |
| ConfigMap содержит корректный IP балансировщика | ✅ | Вывод `kubectl get configmap` |

---

## Ответы на вопросы для отчета

**Вопрос 1:** *Что такое GitOps и в чем его преимущества по сравнению с традиционным CI/CD?*  
**Ответ:** GitOps – это подход к управлению инфраструктурой и приложениями, при котором Git-репозиторий является единственным источником истины (single source of truth) для декларативного описания желаемого состояния системы. ArgoCD постоянно сравнивает состояние кластера с состоянием в Git и автоматически применяет изменения. Преимущества: повышенная прозрачность (все изменения в Git), простота отката, автоматическая синхронизация (self-healing), упрощение аудита.

**Вопрос 2:** *Как ArgoCD синхронизируется с Git-репозиторием?*  
**Ответ:** ArgoCD периодически опрашивает репозиторий (или получает уведомления через webhook) и сравнивает манифесты в Git с текущим состоянием ресурсов в кластере. При обнаружении расхождений ArgoCD может выполнить автоматическую синхронизацию (если включено) или показать diff для ручного применения.

**Вопрос 3:** *Как Terraform может обновлять манифесты Kubernetes (например, ConfigMap) при изменении IP балансировщика?*  
**Ответ:** Можно использовать механизм шаблонизации в Terraform: после применения изменений Terraform генерирует YAML-файл ConfigMap с новым IP, используя `templatefile` или `local_file`. Затем этот файл коммитится и пушится в Git-репозиторий, после чего ArgoCD автоматически подхватывает изменения.

**Вопрос 4:** *Как в Terraform организовано создание двух идентичных ВМ?*  
**Ответ:** Используется мета-аргумент `count`. В блоке ресурса задается `count = 2`, и внутри ресурса используются ссылки на `count.index` для генерации уникальных имен и IP-адресов.

**Вопрос 5:** *Какие преимущества дает использование Kustomize в GitOps-пайплайне?*  
**Ответ:** Kustomize позволяет управлять конфигурацией без шаблонизации, используя патчи и наложения (overlays). Это упрощает поддержку разных окружений (dev/staging/prod) – можно иметь базовые манифесты и переопределять только отличающиеся параметры.

---

## Выводы

В ходе лабораторной работы был реализован полный цикл CI/CD и GitOps для автоматизации развертывания инфраструктуры и приложения:

- Развернута инфраструктура (VPC, веб-серверы, балансировщик) с помощью Terraform с удаленным состоянием в S3.
- Создан кластер Kubernetes и установлен ArgoCD – инструмент GitOps.
- Подготовлены манифесты приложения с использованием Kustomize.
- Выполнена интеграция Terraform и Kubernetes через передачу IP-адреса балансировщика в ConfigMap.
- Настроена автоматическая синхронизация ArgoCD, гарантирующая, что кластер всегда соответствует описанию в Git.

Полученные навыки позволяют строить production-решения с высокой степенью автоматизации, наблюдаемости и надежности.

---

## Оценка затрат

За время выполнения работы (~4 часа) использовались следующие ресурсы:

| Ресурс | Стоимость (руб/час) | Время (часы) | Сумма (руб) |
|--------|---------------------|--------------|-------------|
| Веб-серверы (2 шт., Basic-1-1-10) | ~3×2 | 4 | 24 |
| Балансировщик | ~2 | 4 | 8 |
| Публичный IP (балансировщик) | ~1 | 4 | 4 |
| Бакет S3 (хранение state) | ~0.02 | 4 | 0.08 |
| Кластер Kubernetes (STD3-1-2) | ~10 | 4 | 40 |
| **Итого** | | | **~76** |

Округлённо **≈ 80 руб.** Все ресурсы были удалены после завершения работы.

---

## Приложенные файлы

| Файл | Тип | Описание |
|------|-----|----------|
| `VKC_LR_04_cicd_gitops_main_РемизовКЛ_20260619.tf` | Terraform | Основной файл конфигурации инфраструктуры |
| `VKC_LR_04_cicd_gitops_variables_РемизовКЛ_20260619.tf` | Terraform | Переменные |
| `VKC_LR_04_cicd_gitops_outputs_РемизовКЛ_20260619.tf` | Terraform | Выходные переменные |
| `VKC_LR_04_cicd_gitops_backend_РемизовКЛ_20260619.tf` | Terraform | Настройка бэкенда S3 |
| `VKC_LR_04_cicd_gitops_deployment_РемизовКЛ_20260619.yaml` | Kubernetes | Манифест Deployment |
| `VKC_LR_04_cicd_gitops_service_РемизовКЛ_20260619.yaml` | Kubernetes | Манифест Service |
| `VKC_LR_04_cicd_gitops_configmap_РемизовКЛ_20260619.yaml` | Kubernetes | Манифест ConfigMap |
| `VKC_LR_04_cicd_gitops_kustomization_РемизовКЛ_20260619.yaml` | Kubernetes | Kustomization |
| `VKC_LR_04_cicd_gitops_log_РемизовКЛ_20260619.log` | Лог | Вывод команд |
| Скриншоты | PNG | Настройки ArgoCD, синхронизация, топология, кластер, бакет, ConfigMap |
