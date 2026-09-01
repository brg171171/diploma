# Базовые Terraform-файлы для диплома

Этот каталог содержит стартовую конфигурацию Terraform для Yandex Cloud.
Она создаёт VPC, четыре подсети в двух зонах, NAT gateway, таблицу
маршрутизации приватных подсетей и группы безопасности сервисов.

## Подключение к репозиторию

Скопируйте файлы в каталог `~/diploma/terraform`, затем выполните:

```bash
cd ~/diploma/terraform
cp terraform.tfvars.example terraform.tfvars
chmod 600 terraform.tfvars
```

Заполните в `terraform.tfvars`:

- `cloud_id`;
- `folder_id`;
- актуальные `admin_cidr` и `viewer_cidrs`;
- при необходимости URL репозитория и доменное имя.

Публичный SSH-ключ по умолчанию читается из
`~/.ssh/netology_diploma.pub`. Закрытый ключ Terraform не использует.

## Аутентификация

Токен не хранится в `.tf` или `.tfvars`. Перед запуском экспортируйте его:

```bash
export YC_TOKEN="$(yc iam create-token)"
```

## Инициализация и проверка

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

Перед применением внимательно проверьте план:

```bash
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

После применения должны появиться 1 VPC, 4 подсети, 1 NAT gateway,
1 таблица маршрутизации и 8 групп безопасности.

Проверка через YC CLI:

```bash
yc vpc network list
yc vpc subnet list
yc vpc gateway list
yc vpc route-table list
yc vpc security-group list
```

Официальная инструкция по провайдеру:
https://yandex.cloud/en/docs/terraform/quickstart
