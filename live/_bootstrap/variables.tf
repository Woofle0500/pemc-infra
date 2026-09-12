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

variable "state_bucket_kms_key_alias" {
  type    = string
  default = "alias/woofle-pemc-tfstate"
}