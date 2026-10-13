locals {
  # The landing zone code this module runs. Fixed so every customer gets the
  # same landing zone; change the branch with landing_zone_vcs_branch.
  landing_zone_vcs_repo = "kardell2006g/customer-landing-zone"

  # Organization this module is running in, from TFC_WORKSPACE_SLUG. Null
  # outside HCP Terraform, where the provider falls back to TFE_ORGANIZATION.
  run_organization = var.TFC_WORKSPACE_SLUG != "" ? split("/", var.TFC_WORKSPACE_SLUG)[0] : null
  tfe_organization = data.tfe_organization.current.name

  # "Acme Corp." -> "acme-corp"
  company_slug = trim(replace(lower(var.company_name), "/[^a-z0-9]+/", "-"), "-")
  name         = "${local.company_slug}-${var.environment}"

  # Project names allow letters, digits, spaces, '-' and '_'.
  project_name      = "${trimspace(replace(var.company_name, "/[^A-Za-z0-9 _-]/", ""))} ${var.environment}"
  team_name         = "${local.name}-readers"
  variable_set_name = "${local.name}-aws-landing-zone"

  landing_zone_workspace_name = "lz-${local.name}"

  # adam.kardell@hashicorp.com -> adam.kardell+aws48213@hashicorp.com
  aws_account_email = format(
    "%s+aws%d@%s",
    split("@", var.aws_account_root_mailbox)[0],
    random_integer.account_email.result,
    split("@", var.aws_account_root_mailbox)[1],
  )

  reader_emails = toset([for e in var.reader_emails : lower(trimspace(e))])
}

# Resolves the provider's organization to a name for the resources that need
# it spelled out.
data "tfe_organization" "current" {}

# Random tag for the AWS account email. Generated once per customer and kept
# in state, so the account's email never changes on later applies.
resource "random_integer" "account_email" {
  min = 10000
  max = 99999
}
