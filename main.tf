locals {
  # "Acme Corp." -> "acme-corp"
  company_slug = trim(replace(lower(var.company_name), "/[^a-z0-9]+/", "-"), "-")
  name         = "${local.company_slug}-${var.environment}"

  # Project names allow letters, digits, spaces, '-' and '_'.
  project_name      = "${trimspace(replace(var.company_name, "/[^A-Za-z0-9 _-]/", ""))} ${var.environment}"
  team_name         = "${local.name}-readers"
  variable_set_name = "${local.name}-aws-landing-zone"

  landing_zone_workspace_name = "lz-${local.name}"
  aws_account_email           = "${var.aws_account_email_prefix}+${local.name}@${var.aws_account_email_domain}"

  reader_emails = toset([for e in var.reader_emails : lower(trimspace(e))])
}
