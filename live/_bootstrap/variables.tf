variable "owner" {
  type    = string
  default = "woofle"
}

variable "environment" {
  type    = string
  default = "platform"
}

variable "cost_center" {
  type        = string
  default     = "sre"
  description = "the team responsible for the cost incurred by the resources provisioned; purely for internal budgeting and chargeback"
}

variable "state_bucket_name" {
  type    = string
  default = "woofle-pemc-tfstate"
}

variable "management_cmk_alias" {
  type        = string
  default     = "alias/woofle-pemc-tfstate"
  description = "Alias for the CMK dedicated to the state bucket."
}

variable "tf_run_bucket_name" {
  type        = string
  default     = "woofle-pemc-tf-run"
  description = "Bucket holding per-run Terraform artifacts (plan outputs written by pemc-management-plan, apply outputs written by pemc-management-apply)."
}

variable "tf_run_cmk_alias" {
  type        = string
  default     = "alias/woofle-pemc-tf-run"
  description = "Alias for the CMK dedicated to the tf run bucket."
}