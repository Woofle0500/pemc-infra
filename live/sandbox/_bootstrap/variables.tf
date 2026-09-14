variable "owner" {
  type    = string
  default = "woofle"
}

variable "environment" {
  type    = string
  default = "sandbox"
}

variable "cost_center" {
  type        = string
  default     = "sre"
  description = "the team responsible for the cost incurred by the resources provisioned; purely for internal budgeting and chargeback"
}

variable "state_bucket_arn" {
  type    = string
  default = "arn:aws:s3:::woofle-pemc-tfstate"
}

variable "management_account_root_arn" {
  type        = string
  default     = "arn:aws:iam::730335219774:root"
}

variable "management_sso_admin_role_arn_pattern" {
  type        = string
  default     = "arn:aws:iam::730335219774:role/aws-reserved/sso.amazonaws.com/ap-south-1/AWSReservedSSO_PEMCAdmin*"
  description = "ARN pattern (wildcarded, SSO permission-set roles get a random suffix) of the management account's PEMCAdmin SSO role."
}

variable "state_bucket_kms_cmk_arn" {
  type    = string
  default = "arn:aws:kms:ap-south-1:730335219774:key/2a85860d-07ad-4881-9505-12eb93ca2ecf"
}

variable "oidc_provider_tag" {
  type = map(string)
  default = {
    "pemc:environment" = "platform"
  }
}
