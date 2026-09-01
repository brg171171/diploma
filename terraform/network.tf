resource "yandex_vpc_network" "main" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-vpc"
  description = "Единая VPC дипломной инфраструктуры"
  labels      = local.common_labels
}

# NAT gateway даёт приватным ВМ исходящий доступ в интернет без публичных IP.
resource "yandex_vpc_gateway" "egress" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-nat"
  description = "Исходящий интернет-доступ приватных подсетей"
  labels      = local.common_labels

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-private-rt"
  description = "Маршрут приватных подсетей через NAT gateway"
  network_id  = yandex_vpc_network.main.id
  labels      = local.common_labels

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.egress.id
  }
}

# Публичные подсети: bastion, Grafana, Kibana и узлы ALB.
resource "yandex_vpc_subnet" "public_a" {
  folder_id      = var.folder_id
  name           = "${local.name_prefix}-public-a"
  description    = "Публичная подсеть в ru-central1-a"
  zone           = local.zones.a
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.public_a_cidr]
  labels         = local.common_labels
}

resource "yandex_vpc_subnet" "public_d" {
  folder_id      = var.folder_id
  name           = "${local.name_prefix}-public-d"
  description    = "Публичная подсеть в ru-central1-d"
  zone           = local.zones.d
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.public_d_cidr]
  labels         = local.common_labels
}

# Приватные подсети: Instance Group с web-серверами, Prometheus,
# Elasticsearch и Managed PostgreSQL.
resource "yandex_vpc_subnet" "private_a" {
  folder_id      = var.folder_id
  name           = "${local.name_prefix}-private-a"
  description    = "Приватная подсеть в ru-central1-a"
  zone           = local.zones.a
  network_id     = yandex_vpc_network.main.id
  route_table_id = yandex_vpc_route_table.private.id
  v4_cidr_blocks = [var.private_a_cidr]
  labels         = local.common_labels
}

resource "yandex_vpc_subnet" "private_d" {
  folder_id      = var.folder_id
  name           = "${local.name_prefix}-private-d"
  description    = "Приватная подсеть в ru-central1-d"
  zone           = local.zones.d
  network_id     = yandex_vpc_network.main.id
  route_table_id = yandex_vpc_route_table.private.id
  v4_cidr_blocks = [var.private_d_cidr]
  labels         = local.common_labels
}

