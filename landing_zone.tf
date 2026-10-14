# ---------------------------------------------------------------------------
# AWS landing zone
#
# The landing zone gets its own HCP Terraform workspace in the shared
# "Customer Landing Zones" project, so its state lives there and not in this
# no-code workspace. This module creates that workspace, sets its variables,
# runs it, then reads its outputs into the customer project's variable set.
# ---------------------------------------------------------------------------

# Shared by every customer, so it's looked up rather than created here.
# Create it once before publishing this module.
data "tfe_project" "landing_zones" {
  name = var.landing_zone_project_name
}

# GitHub connection: the HCP Terraform GitHub App (preferred) or, when
# github_app_installation_name is null, a GitHub OAuth VCS provider.
data "tfe_github_app_installation" "this" {
  count = var.github_app_installation_name != null ? 1 : 0

  name = var.github_app_installation_name
}

resource "tfe_workspace" "landing_zone" {
  name              = local.landing_zone_workspace_name
  project_id        = data.tfe_project.landing_zones.id
  description       = "AWS landing zone for ${var.company_name} (${var.environment}). Account root email: ${local.aws_account_email}. Created by the customer-onboarding no-code module."
  working_directory = var.landing_zone_working_directory

  # Applies started by this module are confirmed by tfe_workspace_run below.
  # Runs started by commits to the landing zone repo wait for approval.
  auto_apply     = false
  queue_all_runs = false

  # tfe_workspace_run destroys the landing zone before this workspace is
  # deleted, so its state is normally empty by then. force_delete deletes the
  # workspace even if that destroy left resources behind; they're then
  # orphaned in AWS (tagged "TFC Workspace") and must be cleaned up by hand.
  force_delete = true

  file_triggers_enabled = var.landing_zone_working_directory != ""
  trigger_prefixes      = var.landing_zone_working_directory != "" ? [var.landing_zone_working_directory] : []

  vcs_repo {
    identifier                 = local.landing_zone_vcs_repo
    branch                     = var.landing_zone_vcs_branch
    github_app_installation_id = one(data.tfe_github_app_installation.this[*].id)
    oauth_token_id             = var.vcs_oauth_token_id
  }

  # Search workspaces by aws-email-tag to find the one behind an AWS email.
  tags = {
    company       = local.company_slug
    environment   = var.environment
    aws-email-tag = local.aws_account_email_tag
  }
}

# e.g. the variable set holding AWS management-account credentials.
data "tfe_variable_set" "landing_zone" {
  for_each = toset(var.landing_zone_variable_set_names)

  name = each.value
}

resource "tfe_workspace_variable_set" "landing_zone" {
  for_each = data.tfe_variable_set.landing_zone

  variable_set_id = each.value.id
  workspace_id    = tfe_workspace.landing_zone.id
}

locals {
  landing_zone_vars = {
    company_name       = var.company_name
    environment        = var.environment
    account_name       = local.aws_account_name
    account_email      = local.aws_account_email
    aws_region         = var.aws_region
    vpc_cidr           = var.vpc_cidr
    tfc_hostname       = var.tfe_hostname
    tfc_organization   = local.tfe_organization
    tfc_project_name   = tfe_project.customer.name
    create_deploy_role = tostring(var.aws_dynamic_credentials)
  }
}

resource "tfe_variable" "landing_zone" {
  for_each = local.landing_zone_vars

  workspace_id = tfe_workspace.landing_zone.id
  category     = "terraform"
  key          = each.key
  value        = each.value
}

# Applies the landing zone when this module is applied, and destroys it
# (before its workspace is deleted) when this module is destroyed.
resource "tfe_workspace_run" "landing_zone" {
  workspace_id = tfe_workspace.landing_zone.id

  apply {
    manual_confirm = false
    wait_for_run   = true
    retry_attempts = 3
  }

  destroy {
    manual_confirm = false
    wait_for_run   = true
    retry_attempts = 3
  }

  depends_on = [
    tfe_variable.landing_zone,
    tfe_workspace_variable_set.landing_zone,
  ]
}

# depends_on defers this read to apply time on the first run, when the
# landing zone has no state yet.
data "tfe_outputs" "landing_zone" {
  organization = local.tfe_organization
  workspace    = tfe_workspace.landing_zone.name

  depends_on = [tfe_workspace_run.landing_zone]
}

locals {
  lz = data.tfe_outputs.landing_zone.nonsensitive_values
}
