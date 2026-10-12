locals {
  # "Acme Corp." -> "acme-corp"
  company_slug = trim(replace(lower(var.company_name), "/[^a-z0-9]+/", "-"), "-")
  name         = "${local.company_slug}-${var.environment}"

  project_name           = "${var.company_name} ${var.environment}"
  readers_group_name     = "${local.project_name} Readers"
  variable_group_name    = "${local.name}-aws-landing-zone"
  aws_service_connection = "aws-${local.name}"

  landing_zone_workspace_name = "lz-${local.name}"
  aws_account_email           = "${var.aws_account_email_prefix}+${local.name}@${var.aws_account_email_domain}"

  reader_emails = toset([for e in var.reader_emails : lower(trimspace(e))])
}
