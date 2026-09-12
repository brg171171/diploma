# The secret value is created outside Terraform, so it does not enter tfstate.
# Only its non-secret ID is supplied to Terraform.

variable "filebeat_lockbox_secret_id" {
  description = "ID of the Lockbox secret containing the Filebeat password"
  type        = string
  sensitive   = false

  validation {
    condition     = length(trimspace(var.filebeat_lockbox_secret_id)) > 0
    error_message = "filebeat_lockbox_secret_id must not be empty."
  }
}

resource "yandex_iam_service_account" "web_runtime" {
  folder_id   = var.folder_id
  name        = "${local.name_prefix}-web-runtime"
  description = "Runtime identity of web VMs; reads only the Filebeat secret"
}

resource "yandex_lockbox_secret_iam_member" "web_filebeat_password_reader" {
  secret_id = var.filebeat_lockbox_secret_id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.web_runtime.id}"
}

resource "yandex_iam_service_account_iam_member" "web_ig_uses_runtime_identity" {
  service_account_id = yandex_iam_service_account.web_runtime.id
  role               = "iam.serviceAccounts.user"
  member             = "serviceAccount:${yandex_iam_service_account.web_instance_group.id}"
}
