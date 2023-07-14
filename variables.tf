variable "harness_delegate_namespace" {
  default   = "harness-delegate-ng"
  sensitive = false
}

variable "harness_delegate_name" {
  default   = "harness-delegate"
  sensitive = false
}

variable "harness_delegate_account_id" {
  sensitive = true
}

variable "harness_delegate_token" {
  sensitive = true
}

variable "harness_delegate_manager_endpoint" {
  sensitive = false
}

variable "harness_delegate_docker_image" {
  default   = "harness/delegate:23.06.79707"
  sensitive = false

}

variable "harness_delegate_replicas" {
  default   = "1"
  sensitive = false
}

variable "harness_delegate_upgrader_enabled" {
  default = "false"
}

variable "harness_delegate_selectors" {
  default = "demo"
}

variable "harness_terraform_account_id" {
  sensitive = true
}

variable "harness_terraform_api_key" {
  sensitive = true
}