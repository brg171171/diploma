output "deployment_context" {
  description = "Проверка выбранного облака, каталога, зон и режима экономии."
  value = {
    cloud_id      = var.cloud_id
    folder_id     = var.folder_id
    default_zone  = var.default_zone
    zones         = local.zones
    preemptible   = var.preemptible
    core_fraction = var.core_fraction
  }
}

output "network_plan" {
  description = "План адресации подсетей."
  value       = local.subnet_cidrs
}

output "network_id" {
  description = "ID созданной VPC."
  value       = yandex_vpc_network.main.id
}

output "subnet_ids" {
  description = "ID публичных и приватных подсетей."
  value = {
    public_a  = yandex_vpc_subnet.public_a.id
    public_d  = yandex_vpc_subnet.public_d.id
    private_a = yandex_vpc_subnet.private_a.id
    private_d = yandex_vpc_subnet.private_d.id
  }
}

output "security_group_ids" {
  description = "ID групп безопасности для последующего назначения ресурсам."
  value = {
    bastion       = yandex_vpc_security_group.bastion.id
    alb           = yandex_vpc_security_group.alb.id
    web           = yandex_vpc_security_group.web.id
    prometheus    = yandex_vpc_security_group.prometheus.id
    grafana       = yandex_vpc_security_group.grafana.id
    elasticsearch = yandex_vpc_security_group.elasticsearch.id
    kibana        = yandex_vpc_security_group.kibana.id
    postgresql    = yandex_vpc_security_group.postgresql.id
  }
}

output "resource_name_prefix" {
  description = "Префикс имён будущих ресурсов."
  value       = local.name_prefix
}
