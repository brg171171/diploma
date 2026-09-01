# В каждой группе исходящий трафик разрешён. Входящий трафик разрешается
# только отдельными правилами ниже. Security Groups в Yandex Cloud stateful:
# ответный трафик для разрешённого соединения открывать отдельно не нужно.

resource "yandex_vpc_security_group" "bastion" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-bastion-sg"
  description = "SSH на bastion только с адреса администратора"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description    = "SSH from ADMIN_IP"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }

  egress {
    description    = "Outbound traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "alb" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-alb-sg"
  description = "HTTP, HTTPS и служебные health checks ALB"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description    = "Public HTTP listener"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = var.site_cidrs
  }

  ingress {
    description    = "Public HTTPS listener"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = var.site_cidrs
  }

  ingress {
    description       = "ALB node health checks"
    protocol          = "TCP"
    port              = 30080
    predefined_target = "loadbalancer_healthchecks"
  }

  # ALB-группа не ссылается в egress на другую SG: это ограничение ALB.
  egress {
    description    = "Traffic to backends"
    protocol       = "ANY"
    v4_cidr_blocks = local.all_subnet_cidrs
  }
}

resource "yandex_vpc_security_group" "web" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-web-sg"
  description = "Web-серверы Instance Group"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description       = "HTTP from ALB"
    protocol          = "TCP"
    port              = 80
    security_group_id = yandex_vpc_security_group.alb.id
  }

  ingress {
    description       = "ALB backend health checks"
    protocol          = "TCP"
    port              = 80
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    description       = "Node Exporter from Prometheus"
    protocol          = "TCP"
    port              = 9100
    security_group_id = yandex_vpc_security_group.prometheus.id
  }

  ingress {
    description       = "Nginx Log Exporter from Prometheus"
    protocol          = "TCP"
    port              = 4040
    security_group_id = yandex_vpc_security_group.prometheus.id
  }

  egress {
    description    = "Updates, DNS and log delivery"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "prometheus" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-prometheus-sg"
  description = "Prometheus, Alertmanager и PostgreSQL adapter"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description    = "Prometheus API from Grafana"
    protocol       = "TCP"
    port           = 9090
    v4_cidr_blocks = ["${local.private_ips.grafana}/32"]
  }

  ingress {
    description       = "Node Exporter from Prometheus itself"
    protocol          = "TCP"
    port              = 9100
    predefined_target = "self_security_group"
  }

  # 9093 (Alertmanager) и 9201 (PostgreSQL adapter) остаются локальными.
  # Для диагностики используйте SSH port forwarding через bastion.
  egress {
    description    = "Scraping, remote write, updates and log delivery"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "grafana" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-grafana-sg"
  description = "Публичный интерфейс Grafana"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description    = "Grafana UI"
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = local.effective_viewer_cidrs
  }

  ingress {
    description       = "Node Exporter from Prometheus"
    protocol          = "TCP"
    port              = 9100
    security_group_id = yandex_vpc_security_group.prometheus.id
  }

  egress {
    description    = "Prometheus access, updates and log delivery"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "elasticsearch" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-elasticsearch-sg"
  description = "Приватный Elasticsearch и приём Filebeat"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description       = "Elasticsearch API from web Filebeat"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.web.id
  }

  ingress {
    description       = "Elasticsearch API from Prometheus host Filebeat"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.prometheus.id
  }

  ingress {
    description       = "Elasticsearch API from Grafana host Filebeat"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.grafana.id
  }

  ingress {
    description       = "Elasticsearch API from Kibana and its Filebeat"
    protocol          = "TCP"
    port              = 9200
    security_group_id = yandex_vpc_security_group.kibana.id
  }

  ingress {
    description       = "Node Exporter from Prometheus"
    protocol          = "TCP"
    port              = 9100
    security_group_id = yandex_vpc_security_group.prometheus.id
  }

  egress {
    description    = "Updates and outbound integrations"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "kibana" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-kibana-sg"
  description = "Публичный интерфейс Kibana"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  ingress {
    description    = "Kibana UI"
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = local.effective_viewer_cidrs
  }

  ingress {
    description       = "Node Exporter from Prometheus"
    protocol          = "TCP"
    port              = 9100
    security_group_id = yandex_vpc_security_group.prometheus.id
  }

  egress {
    description    = "Elasticsearch access, updates and log delivery"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "postgresql" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-postgresql-sg"
  description = "Managed PostgreSQL для remote_write Prometheus"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  ingress {
    description       = "PostgreSQL from adapter on Prometheus host"
    protocol          = "TCP"
    port              = 6432
    security_group_id = yandex_vpc_security_group.prometheus.id
  }

  ingress {
    description       = "Traffic between cluster hosts"
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Managed service outbound traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
