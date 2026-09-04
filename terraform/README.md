# Базовые Terraform-файлы для диплома

Этот каталог содержит стартовую конфигурацию Terraform для Yandex Cloud.
Она создаёт VPC, четыре подсети в двух зонах, NAT gateway, таблицу
маршрутизации приватных подсетей, группы безопасности и пять постоянных ВМ.
Bastion, Grafana и Kibana по умолчанию получают динамические публичные IPv4,
не расходуя квоту статических адресов.

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
1 таблица маршрутизации, 8 групп безопасности и 5 ВМ. Три публичных IPv4
будут автоматически назначены сетевым интерфейсам публичных ВМ.

Проверка через YC CLI:

```bash
yc vpc network list
yc vpc subnet list
yc vpc gateway list
yc vpc route-table list
yc vpc security-group list
yc vpc address list
yc compute instance list
```

Проверка cloud-init и SSH:

```bash
BASTION_IP="$(terraform output -raw bastion_public_ip)"
ssh -i ~/.ssh/netology_diploma \
  -o StrictHostKeyChecking=accept-new \
  ubuntu@"$BASTION_IP" \
  'cloud-init status --wait; hostname; cat /etc/diploma/instance.yml'
```

Проверка приватных ВМ через bastion:

```bash
ssh -i ~/.ssh/netology_diploma \
  -J ubuntu@"$BASTION_IP" \
  ubuntu@10.10.11.20 \
  'cloud-init status --wait; hostname; curl -I https://packages.ubuntu.com'

ssh -i ~/.ssh/netology_diploma \
  -J ubuntu@"$BASTION_IP" \
  ubuntu@10.10.11.30 \
  'cloud-init status --wait; hostname; free -h; lsblk'
```

Официальная инструкция по провайдеру:
https://yandex.cloud/en/docs/terraform/quickstart
