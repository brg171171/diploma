# Backend Group направляет HTTP-трафик на автоматически созданную
# Target Group из yandex_compute_instance_group.web.
resource "yandex_alb_backend_group" "web" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-web-bg"
  description = "HTTP backend group for fault-tolerant nginx servers"
  labels      = local.common_labels

  http_backend {
    name   = "web-http-backend"
    weight = 1
    port   = 80
    target_group_ids = [
      yandex_compute_instance_group.web.application_load_balancer[0].target_group_id
    ]

    load_balancing_config {
      panic_threshold = 50
    }

    healthcheck {
      timeout             = "3s"
      interval            = "5s"
      healthcheck_port    = 80
      healthy_threshold   = 2
      unhealthy_threshold = 2

      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "web" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-web-router"
  description = "HTTP router for the diploma website"
  labels      = local.common_labels
}

resource "yandex_alb_virtual_host" "web" {
  name           = "${local.name_prefix}-web-vhost"
  http_router_id = yandex_alb_http_router.web.id

  route {
    name = "site-root-route"

    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }

      http_route_action {
        backend_group_id = yandex_alb_backend_group.web.id
        timeout          = "60s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web" {
  folder_id          = var.folder_id
  name               = "${local.name_prefix}-web-alb"
  description        = "Public multi-zone Application Load Balancer"
  network_id         = yandex_vpc_network.main.id
  security_group_ids = [yandex_vpc_security_group.alb.id]
  labels             = local.common_labels

  allocation_policy {
    location {
      zone_id   = local.zones.a
      subnet_id = yandex_vpc_subnet.public_a.id
    }

    location {
      zone_id   = local.zones.d
      subnet_id = yandex_vpc_subnet.public_d.id
    }
  }

  listener {
    name = "http"

    endpoint {
      address {
        # Пустой блок запрашивает автоматически назначаемый публичный IPv4.
        # Ресурс yandex_vpc_address и квота статических адресов не нужны.
        external_ipv4_address {}
      }
      ports = [80]
    }

    http {
      handler {
        http_router_id = yandex_alb_http_router.web.id
      }
    }
  }

  depends_on = [yandex_alb_virtual_host.web]
}
