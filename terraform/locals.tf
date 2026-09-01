locals {
  name_prefix = "${var.project_name}-${var.environment}"

  zones = {
    a = "ru-central1-a"
    d = "ru-central1-d"
  }

  subnet_cidrs = {
    public_a  = var.public_a_cidr
    public_d  = var.public_d_cidr
    private_a = var.private_a_cidr
    private_d = var.private_d_cidr
  }

  all_subnet_cidrs = values(local.subnet_cidrs)

  # Если viewer_cidrs не задан, Grafana и Kibana доступны только с ADMIN_IP.
  effective_viewer_cidrs = length(var.viewer_cidrs) > 0 ? var.viewer_cidrs : [var.admin_cidr]

  # Адреса зарезервированы для одиночных ВМ. Веб-серверы Instance Group
  # получают динамические адреса из приватных подсетей.
  private_ips = {
    bastion       = "10.10.10.10"
    grafana       = "10.10.10.20"
    kibana        = "10.10.10.30"
    prometheus    = "10.10.11.20"
    elasticsearch = "10.10.11.30"
  }

  common_labels = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed-by  = "terraform"
    },
    var.extra_labels
  )

  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}
