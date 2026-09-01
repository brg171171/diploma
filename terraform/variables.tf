variable "admin_cidr" {
  description = "Публичный IPv4 администратора для SSH к bastion"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr должен быть указан в формате IPv4 CIDR, например 95.84.198.105/32."
  }
}

variable "viewer_cidrs" {
  description = "Адреса, которым разрешён доступ к Grafana и Kibana"
  type        = list(string)

  validation {
    condition = alltrue([
      for cidr in var.viewer_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Каждый адрес viewer_cidrs должен быть указан в формате CIDR."
  }
}
