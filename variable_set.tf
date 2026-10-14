# ---------------------------------------------------------------------------
# Variable set attached to the customer project, carrying the landing zone's
# values to every workspace in it.
#
# The landing zone is currently a dummy (no real AWS account), so AWS dynamic
# credentials (TFC_AWS_PROVIDER_AUTH / TFC_AWS_RUN_ROLE_ARN) are not set: a
# fake role ARN would make every AWS provider in the project fail to
# authenticate. Add them back when the landing zone creates real accounts.
# ---------------------------------------------------------------------------

resource "tfe_variable_set" "customer" {
  name        = local.variable_set_name
  description = "AWS landing zone settings for ${var.company_name} (${var.environment}). Managed by the customer-onboarding no-code module; manual edits are overwritten."
}

resource "tfe_project_variable_set" "customer" {
  project_id      = tfe_project.customer.id
  variable_set_id = tfe_variable_set.customer.id
}

locals {
  variable_set_env = {
    AWS_REGION = local.lz["aws_region"]
  }

  # Workspaces that declare these variables pick them up; ones that don't
  # just get an "undeclared variable" warning.
  variable_set_terraform = {
    company_name         = { value = var.company_name, hcl = false }
    environment          = { value = var.environment, hcl = false }
    aws_account_id       = { value = local.lz["account_id"], hcl = false }
    aws_account_name     = { value = local.aws_account_name, hcl = false }
    aws_account_is_dummy = { value = tostring(local.lz["is_dummy"]), hcl = true }
    aws_region           = { value = local.lz["aws_region"], hcl = false }
    aws_deploy_role_arn  = { value = local.lz["deploy_role_arn"], hcl = false }
    vpc_id               = { value = local.lz["vpc_id"], hcl = false }
    public_subnet_ids    = { value = jsonencode(local.lz["public_subnet_ids"]), hcl = true }
    private_subnet_ids   = { value = jsonencode(local.lz["private_subnet_ids"]), hcl = true }
  }
}

resource "tfe_variable" "customer_env" {
  for_each = local.variable_set_env

  variable_set_id = tfe_variable_set.customer.id
  category        = "env"
  key             = each.key
  value           = each.value
}

resource "tfe_variable" "customer_terraform" {
  for_each = local.variable_set_terraform

  variable_set_id = tfe_variable_set.customer.id
  category        = "terraform"
  key             = each.key
  value           = each.value.value
  hcl             = each.value.hcl
}
