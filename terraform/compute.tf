# Prometheus будет получать список динамических web-узлов Instance Group
# через YC API. Других ролей этому service account не требуется.
resource "yandex_iam_service_account" "prometheus_discovery" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-prom-discovery"
  description = "Read-only discovery of Compute instances for Prometheus"
}

resource "yandex_resourcemanager_folder_iam_member" "prometheus_discovery_viewer" {
  folder_id = var.folder_id
  role      = "compute.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.prometheus_discovery.id}"
}

locals {
  vm_definitions = {
    bastion = {
      hostname           = "bastion-01"
      role               = "bastion"
      zone               = local.zones.a
      subnet_id          = yandex_vpc_subnet.public_a.id
      ip_address         = local.private_ips.bastion
      nat                = true
      security_group_ids = [yandex_vpc_security_group.bastion.id]
      service_account_id = null
    }
    prometheus = {
      hostname           = "prometheus-01"
      role               = "prometheus"
      zone               = local.zones.a
      subnet_id          = yandex_vpc_subnet.private_a.id
      ip_address         = local.private_ips.prometheus
      nat                = false
      security_group_ids = [yandex_vpc_security_group.prometheus.id]
      service_account_id = yandex_iam_service_account.prometheus_discovery.id
    }
    grafana = {
      hostname           = "grafana-01"
      role               = "grafana"
      zone               = local.zones.a
      subnet_id          = yandex_vpc_subnet.public_a.id
      ip_address         = local.private_ips.grafana
      nat                = true
      security_group_ids = [yandex_vpc_security_group.grafana.id]
      service_account_id = null
    }
    elasticsearch = {
      hostname           = "elasticsearch-01"
      role               = "elasticsearch"
      zone               = local.zones.a
      subnet_id          = yandex_vpc_subnet.private_a.id
      ip_address         = local.private_ips.elasticsearch
      nat                = false
      security_group_ids = [yandex_vpc_security_group.elasticsearch.id]
      service_account_id = null
    }
    kibana = {
      hostname           = "kibana-01"
      role               = "kibana"
      zone               = local.zones.a
      subnet_id          = yandex_vpc_subnet.public_a.id
      ip_address         = local.private_ips.kibana
      nat                = true
      security_group_ids = [yandex_vpc_security_group.kibana.id]
      service_account_id = null
    }
  }

  static_public_vm_definitions = {
    for name, definition in local.vm_definitions :
    name => definition if contains(var.static_public_ip_roles, name)
  }
}

# По умолчанию for_each пустой: публичные ВМ получают динамические адреса.
# Добавьте имя роли в static_public_ip_roles только при наличии статической квоты.
resource "yandex_vpc_address" "public_vm" {
  for_each = local.static_public_vm_definitions

  folder_id           = var.folder_id
  name                = "${local.name_prefix}-${each.key}-ip"
  description         = "Static public IPv4 for ${each.value.hostname}"
  deletion_protection = false
  labels              = merge(local.common_labels, { role = each.value.role })

  external_ipv4_address {
    zone_id = each.value.zone
  }
}

resource "yandex_compute_instance" "service" {
  for_each = local.vm_definitions

  folder_id                 = var.folder_id
  name                      = each.value.hostname
  hostname                  = each.value.hostname
  description               = "Diploma infrastructure: ${each.value.role}"
  zone                      = each.value.zone
  platform_id               = var.platform_id
  allow_stopping_for_update = true
  service_account_id        = each.value.service_account_id
  labels                    = merge(local.common_labels, { role = each.value.role })

  resources {
    cores         = var.vm_resources[each.key].cores
    memory        = var.vm_resources[each.key].memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    auto_delete = true
    mode        = "READ_WRITE"

    initialize_params {
      name        = "${local.name_prefix}-${each.key}-boot"
      description = "Boot disk for ${each.value.hostname}"
      image_id    = var.ubuntu_image_id
      size        = var.vm_resources[each.key].disk_size
      type        = var.vm_resources[each.key].disk_type
    }
  }

  network_interface {
    subnet_id  = each.value.subnet_id
    ip_address = each.value.ip_address
    nat        = each.value.nat
    # null при отсутствии роли в static_public_ip_roles означает:
    # выделить динамический публичный IPv4 автоматически.
    nat_ip_address = try(
      yandex_vpc_address.public_vm[each.key].external_ipv4_address[0].address,
      null
    )
    security_group_ids = each.value.security_group_ids
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      hostname_yaml       = jsonencode(each.value.hostname)
      final_message_yaml  = jsonencode("Cloud-init completed for ${each.value.hostname}")
      project_name_yaml   = jsonencode(var.project_name)
      role_yaml           = jsonencode(each.value.role)
      ssh_public_key_yaml = jsonencode(local.ssh_public_key)
      ssh_user_yaml       = jsonencode(var.ssh_user)
      timezone_yaml       = jsonencode(var.timezone)
    })
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.prometheus_discovery_viewer
  ]
}
