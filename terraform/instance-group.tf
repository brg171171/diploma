# Service account от имени которого Compute Instance Group создаёт,
# заменяет и удаляет web-ВМ, а также поддерживает ALB Target Group.
resource "yandex_iam_service_account" "web_instance_group" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-web-ig"
  description = "Service account for web Instance Group and ALB integration"
}

resource "yandex_resourcemanager_folder_iam_member" "web_ig_compute_editor" {
  folder_id = var.folder_id
  role      = "compute.editor"
  member    = "serviceAccount:${yandex_iam_service_account.web_instance_group.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "web_ig_alb_editor" {
  folder_id = var.folder_id
  role      = "alb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.web_instance_group.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "web_ig_vpc_user" {
  folder_id = var.folder_id
  role      = "vpc.user"
  member    = "serviceAccount:${yandex_iam_service_account.web_instance_group.id}"
}

resource "yandex_compute_instance_group" "web" {
  folder_id           = var.folder_id
  name                = "${local.name_prefix}-web-ig"
  description         = "Fault-tolerant nginx web servers in two availability zones"
  service_account_id  = yandex_iam_service_account.web_instance_group.id
  deletion_protection = false
  labels              = merge(local.common_labels, { role = "web" })

  instance_template {
    name        = "${local.name_prefix}-web-{instance.index}"
    hostname    = "web-{instance.index}"
    description = "Managed nginx web server"
    platform_id = var.platform_id
    labels      = merge(local.common_labels, { role = "web" })

    resources {
      cores         = var.web_vm_resources.cores
      memory        = var.web_vm_resources.memory
      core_fraction = 100
    }

    boot_disk {
      mode = "READ_WRITE"

      initialize_params {
        image_id = var.ubuntu_image_id
        size     = var.web_vm_resources.disk_size
        type     = var.web_vm_resources.disk_type
      }
    }

    network_interface {
      network_id = yandex_vpc_network.main.id
      subnet_ids = [
        yandex_vpc_subnet.private_a.id,
        yandex_vpc_subnet.private_d.id,
      ]
      nat                = false
      security_group_ids = [yandex_vpc_security_group.web.id]
    }

    metadata = {
      "config-version" = var.web_config_version

      user-data = templatefile("${path.module}/templates/web-cloud-init.yaml.tftpl", {
        ssh_public_key      = trimspace(file(pathexpand(var.ssh_public_key_path)))
        project_name_yaml   = jsonencode(var.project_name)
        ssh_public_key_yaml = jsonencode(local.ssh_public_key)
        ssh_user_yaml       = jsonencode(var.ssh_user)
        timezone_yaml       = jsonencode(var.timezone)
        git_repo_url_shell  = jsonencode(var.git_repo_url)
        git_revision_shell  = jsonencode(var.git_revision)
      })
    }

    scheduling_policy {
      preemptible = var.preemptible
    }

    network_settings {
      type = "STANDARD"
    }
  }

  # ZONAL поддерживает минимум min_zone_size в каждой выбранной зоне.
  # При max_size = 3 возможна схема 2+1; это соответствует условию диплома
  # и не превышает общую квоту в 8 ВМ вместе с пятью постоянными ВМ.
  scale_policy {
    auto_scale {
      auto_scale_type        = "ZONAL"
      initial_size           = 2
      min_zone_size          = 1
      max_size               = 3
      cpu_utilization_target = 60
      measurement_duration   = 60
      warmup_duration        = 120
      stabilization_duration = 300
    }
  }

  allocation_policy {
    zones = [
      local.zones.a,
      local.zones.d,
    ]
  }

  deploy_policy {
    max_unavailable  = 1
    max_creating     = 2
    max_expansion    = 1
    max_deleting     = 1
    startup_duration = 300
  }

  # Instance Group использует эту проверку для автоматического
  # восстановления неисправных экземпляров.
  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3

    http_options {
      port = 80
      path = "/"
    }
  }

  # Target Group создаётся автоматически и далее подключается в alb.tf.
  application_load_balancer {
    target_group_name            = "${local.name_prefix}-web-tg"
    target_group_description     = "Managed targets of the web Instance Group"
    target_group_labels          = merge(local.common_labels, { role = "web" })
    ignore_health_checks         = false
    max_opening_traffic_duration = 300
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.web_ig_compute_editor,
    yandex_resourcemanager_folder_iam_member.web_ig_alb_editor,
    yandex_resourcemanager_folder_iam_member.web_ig_vpc_user,
  ]
}
