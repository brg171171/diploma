# Отказоустойчивая инфраструктура сайта в Yandex Cloud

Курсовая работа по развёртыванию отказоустойчивой инфраструктуры
с использованием Terraform и Ansible.

## Компоненты

- Yandex Cloud VPC
- Application Load Balancer
- Compute Instance Group
- Nginx
- Prometheus
- Alertmanager
- Grafana
- Elasticsearch
- Kibana
- Filebeat
- Managed Service for PostgreSQL
- Certificate Manager
- Cloud DNS
- Snapshot Schedule

## Структура

- `terraform/` — облачная инфраструктура
- `ansible/` — настройка операционных систем и сервисов
- `monitoring/` — конфигурации мониторинга
- `scripts/` — вспомогательные скрипты
- `evidence/` — результаты тестирования и материалы защиты

## Безопасность

Секреты, приватные ключи, `terraform.tfvars`, Terraform state
и открытый файл Ansible Vault не должны попадать в репозиторий.
