# ---------------------------------------------------------------------------
# Customer project: where the customer's own workspaces will live.
# ---------------------------------------------------------------------------

resource "tfe_project" "customer" {
  name        = local.project_name
  description = "${var.company_name} (${var.environment}). Created by the customer-onboarding no-code module."

  # Test only: every workspace in the project is destroyed after
  # test_auto_destroy_duration without activity, unless it overrides this.
  auto_destroy_activity_duration = local.auto_destroy_duration
}

# ---------------------------------------------------------------------------
# Read-only team
# ---------------------------------------------------------------------------

resource "tfe_team" "readers" {
  name       = local.team_name
  visibility = "organization"

  # No organization-level permissions; access comes only from the project.
  organization_access {
    read_projects   = false
    read_workspaces = false
  }
}

# "read": view workspaces, runs, variables and state in the project. No
# plans, applies or edits.
resource "tfe_team_project_access" "readers" {
  team_id    = tfe_team.readers.id
  project_id = tfe_project.customer.id
  access     = "read"
}

# ---------------------------------------------------------------------------
# Organization members: the readers, plus the customer contact (needed so
# HCP Terraform can email them notifications).
#
# A user must belong to the organization before joining a team or receiving
# notification emails. For an email that isn't a member yet this sends an
# invitation; it takes effect once they accept.
# ---------------------------------------------------------------------------

moved {
  from = tfe_organization_membership.readers
  to   = tfe_organization_membership.members
}

resource "tfe_organization_membership" "members" {
  for_each = setunion(local.reader_emails, [local.customer_email])

  email = each.value
}

# Only reader_emails join the read-only team. Add customer_email to
# reader_emails too if the customer should see the project.
resource "tfe_team_organization_members" "readers" {
  count = length(local.reader_emails) > 0 ? 1 : 0

  team_id                     = tfe_team.readers.id
  organization_membership_ids = [for e in local.reader_emails : tfe_organization_membership.members[e].id]
}
