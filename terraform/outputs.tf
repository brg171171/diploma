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

output "bastion_public_ip" {
  description = "Назначенный публичный IPv4 bastion."
  value       = yandex_compute_instance.service["bastion"].network_interface[0].nat_ip_address
}

output "grafana_public_ip" {
  description = "Назначенный публичный IPv4 Grafana."
  value       = yandex_compute_instance.service["grafana"].network_interface[0].nat_ip_address
}

output "kibana_public_ip" {
  description = "Назначенный публичный IPv4 Kibana."
  value       = yandex_compute_instance.service["kibana"].network_interface[0].nat_ip_address
}

output "service_private_ips" {
  description = "Внутренние адреса пяти постоянных ВМ."
  value = {
    for name, instance in yandex_compute_instance.service :
    name => instance.network_interface[0].ip_address
  }
}

output "service_instance_ids" {
  description = "ID постоянных ВМ для snapshots и диагностики."
  value = {
    for name, instance in yandex_compute_instance.service :
    name => instance.id
  }
}

output "service_boot_disk_ids" {
  description = "ID загрузочных дисков постоянных ВМ для snapshot schedule."
  value = {
    for name, instance in yandex_compute_instance.service :
    name => instance.boot_disk[0].disk_id
  }
}

output "ssh_bastion_command" {
  description = "Команда подключения к bastion."
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${yandex_compute_instance.service["bastion"].network_interface[0].nat_ip_address}"
}

output "web_instance_group_id" {
  description = "ID управляемой группы отказоустойчивых web-серверов."
  value       = yandex_compute_instance_group.web.id
}

output "web_target_group_id" {
  description = "ID автоматически созданной ALB Target Group."
  value       = yandex_compute_instance_group.web.application_load_balancer[0].target_group_id
}

output "web_instance_private_ips" {
  description = "Текущие внутренние IPv4 web-узлов; список меняется при масштабировании."
  value = [
    for instance in yandex_compute_instance_group.web.instances :
    instance.network_interface[0].ip_address
  ]
}

output "alb_public_ip" {
  description = "Динамический публичный IPv4 Application Load Balancer."
  value       = yandex_alb_load_balancer.web.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
}

output "site_url" {
  description = "URL сайта через HTTP listener Application Load Balancer."
  value       = "http://${yandex_alb_load_balancer.web.listener[0].endpoint[0].address[0].external_ipv4_address[0].address}"
}
