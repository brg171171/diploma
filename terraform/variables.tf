variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud."
  type        = string

  validation {
    condition     = length(trimspace(var.cloud_id)) > 0
    error_message = "Укажите cloud_id из команды: yc config get cloud-id."
  }
}

variable "folder_id" {
  description = "Идентификатор каталога Yandex Cloud."
  type        = string

  validation {
    condition     = length(trimspace(var.folder_id)) > 0
    error_message = "Укажите folder_id из команды: yc config get folder-id."
  }
}

variable "default_zone" {
  description = "Зона по умолчанию для ресурсов без явно указанной зоны."
  type        = string
  default     = "ru-central1-a"

  validation {
    condition     = contains(["ru-central1-a", "ru-central1-b", "ru-central1-d"], var.default_zone)
    error_message = "default_zone должна быть ru-central1-a, ru-central1-b или ru-central1-d."
  }
}

variable "project_name" {
  description = "Короткое имя проекта, используемое в именах ресурсов."
  type        = string
  default     = "netology-diploma"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.project_name))
    error_message = "project_name: 3-32 символа, строчные латинские буквы, цифры и дефисы; первый символ — буква."
  }
}

variable "environment" {
  description = "Имя окружения для меток ресурсов."
  type        = string
  default     = "diploma"
}

variable "admin_cidr" {
  description = "Публичный IPv4-адрес администратора в формате x.x.x.x/32 для доступа к bastion по SSH."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && can(regex("/32$", var.admin_cidr))
    error_message = "admin_cidr должен быть корректным IPv4 CIDR с маской /32, например 203.0.113.10/32."
  }
}

variable "viewer_cidrs" {
  description = "CIDR-сети, которым разрешён доступ к Grafana и Kibana. Пустой список заменяется на admin_cidr."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.viewer_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Каждый элемент viewer_cidrs должен быть корректной CIDR-сетью."
  }
}

variable "site_cidrs" {
  description = "CIDR-сети, которым доступны HTTP/HTTPS listeners сайта."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.site_cidrs) > 0 && alltrue([for cidr in var.site_cidrs : can(cidrhost(cidr, 0))])
    error_message = "site_cidrs должен содержать хотя бы одну корректную CIDR-сеть."
  }
}

variable "ssh_user" {
  description = "Linux-пользователь, создаваемый cloud-init."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Локальный путь к открытому SSH-ключу."
  type        = string
  default     = "~/.ssh/netology_diploma.pub"

  validation {
    condition     = can(regex("\\.pub$", var.ssh_public_key_path))
    error_message = "ssh_public_key_path must point to a public key file ending with .pub."
  }
}

variable "ssh_private_key_path" {
  description = "Локальный путь к закрытому SSH-ключу для формируемых команд подключения."
  type        = string
  default     = "~/.ssh/netology_diploma"
}

variable "image_family" {
  description = "Семейство образа ОС для ВМ."
  type        = string
  default     = "ubuntu-2404-lts"
}

variable "platform_id" {
  description = "Платформа Compute Cloud для ВМ."
  type        = string
  default     = "standard-v3"
}

variable "preemptible" {
  description = "Использовать прерываемые ВМ для экономии средств."
  type        = bool
  default     = true
}

variable "core_fraction" {
  description = "Гарантированная доля производительности vCPU в процентах."
  type        = number
  default     = 20

  validation {
    condition     = contains([20, 50, 100], var.core_fraction)
    error_message = "core_fraction должна быть 20, 50 или 100."
  }
}

variable "timezone" {
  description = "Часовой пояс гостевых ОС."
  type        = string
  default     = "Europe/Moscow"

  validation {
    condition     = length(trimspace(var.timezone)) > 0
    error_message = "timezone не должна быть пустой."
  }
}

variable "vm_resources" {
  description = "Ресурсы пяти постоянных ВМ: vCPU, RAM и загрузочный диск."
  type = map(object({
    cores     = number
    memory    = number
    disk_size = number
    disk_type = string
  }))

  default = {
    bastion = {
      cores     = 2
      memory    = 1
      disk_size = 10
      disk_type = "network-hdd"
    }
    prometheus = {
      cores     = 2
      memory    = 2
      disk_size = 20
      disk_type = "network-hdd"
    }
    grafana = {
      cores     = 2
      memory    = 2
      disk_size = 10
      disk_type = "network-hdd"
    }
    elasticsearch = {
      cores     = 2
      memory    = 4
      disk_size = 20
      disk_type = "network-hdd"
    }
    kibana = {
      cores     = 2
      memory    = 2
      disk_size = 10
      disk_type = "network-hdd"
    }
  }

  validation {
    condition = alltrue([
      for name in ["bastion", "prometheus", "grafana", "elasticsearch", "kibana"] :
      contains(keys(var.vm_resources), name)
    ])
    error_message = "vm_resources должен содержать bastion, prometheus, grafana, elasticsearch и kibana."
  }

  validation {
    condition = alltrue([
      for config in values(var.vm_resources) :
      config.cores >= 2 &&
      config.memory >= 1 &&
      config.disk_size >= 10 &&
      contains(["network-hdd", "network-ssd"], config.disk_type)
    ])
    error_message = "Для каждой ВМ: cores >= 2, memory >= 1 ГБ, disk_size >= 10 ГБ, disk_type network-hdd или network-ssd."
  }

  validation {
    condition     = try(var.vm_resources["elasticsearch"].memory >= 4, false)
    error_message = "Для Elasticsearch требуется не менее 4 ГБ RAM."
  }
}

variable "web_vm_resources" {
  description = "Ресурсы одного web-сервера в управляемой Instance Group."
  type = object({
    cores     = number
    memory    = number
    disk_size = number
    disk_type = string
  })

  default = {
    cores     = 2
    memory    = 2
    disk_size = 10
    disk_type = "network-hdd"
  }

  validation {
    condition = (
      var.web_vm_resources.cores >= 2 &&
      var.web_vm_resources.memory >= 1 &&
      var.web_vm_resources.disk_size >= 10 &&
      contains(["network-hdd", "network-ssd"], var.web_vm_resources.disk_type)
    )
    error_message = "Web VM: cores >= 2, memory >= 1 ГБ, disk_size >= 10 ГБ, тип network-hdd или network-ssd."
  }
}

variable "static_public_ip_roles" {
  description = "Публичные ВМ, которым нужно резервировать статический IPv4. Пустой список использует динамические адреса."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for role in var.static_public_ip_roles :
      contains(["bastion", "grafana", "kibana"], role)
    ])
    error_message = "Статический адрес можно включить только для bastion, grafana или kibana."
  }

  validation {
    condition     = length(var.static_public_ip_roles) <= 2
    error_message = "В конфигурации разрешено резервировать не более двух статических публичных IPv4."
  }
}

variable "public_a_cidr" {
  description = "CIDR публичной подсети в зоне ru-central1-a."
  type        = string
  default     = "10.10.10.0/24"

  validation {
    condition     = can(cidrhost(var.public_a_cidr, 0))
    error_message = "public_a_cidr должен быть корректной CIDR-сетью."
  }
}

variable "public_d_cidr" {
  description = "CIDR публичной подсети в зоне ru-central1-d."
  type        = string
  default     = "10.10.20.0/24"

  validation {
    condition     = can(cidrhost(var.public_d_cidr, 0))
    error_message = "public_d_cidr должен быть корректной CIDR-сетью."
  }
}

variable "private_a_cidr" {
  description = "CIDR приватной подсети в зоне ru-central1-a."
  type        = string
  default     = "10.10.11.0/24"

  validation {
    condition     = can(cidrhost(var.private_a_cidr, 0))
    error_message = "private_a_cidr должен быть корректной CIDR-сетью."
  }
}

variable "private_d_cidr" {
  description = "CIDR приватной подсети в зоне ru-central1-d."
  type        = string
  default     = "10.10.21.0/24"

  validation {
    condition     = can(cidrhost(var.private_d_cidr, 0))
    error_message = "private_d_cidr должен быть корректной CIDR-сетью."
  }
}

variable "git_repo_url" {
  description = "Public Git repository used by ansible-pull"
  type        = string

  validation {
    condition     = can(regex("^https://github\\.com/.+\\.git$", var.git_repo_url))
    error_message = "git_repo_url must be a public GitHub HTTPS repository ending with .git"
  }
}

variable "git_revision" {
  description = "Ветка или тег репозитория."
  type        = string
  default     = "main"
}

variable "domain_name" {
  description = "Домен сайта без протокола. Оставьте пустым до настройки Cloud DNS."
  type        = string
  default     = ""
}

variable "dns_zone_id" {
  description = "ID существующей публичной зоны Cloud DNS. Оставьте пустым, если зону будет создавать Terraform."
  type        = string
  default     = ""
}

variable "extra_labels" {
  description = "Дополнительные метки для ресурсов."
  type        = map(string)
  default     = {}
}

variable "ubuntu_image_id" {
  description = "Pinned Ubuntu image ID used by Compute instances"
  type        = string

  validation {
    condition     = can(regex("^fd[0-9a-z]+$", var.ubuntu_image_id))
    error_message = "ubuntu_image_id must be a valid Yandex Cloud image ID."
  }
}

variable "web_config_version" {
  description = "Version marker that triggers a rolling update of the web instance group"
  type        = string
  default     = "ansible-pull-v1"
}

