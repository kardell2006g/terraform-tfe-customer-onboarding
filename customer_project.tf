# ---------------------------------------------------------------------------
# Customer project: where the customer's own workspaces will live.
# ---------------------------------------------------------------------------

resource "tfe_project" "customer" {
  name        = local.project_name
  description = "${var.company_name} (${var.environment}). Created by the customer-onboarding no-code module."
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
# Team members
#
# A user must belong to the organization before joining a team. For an email
# that isn't a member yet this sends an invitation; they show up in the team
# once they accept.
# ---------------------------------------------------------------------------

resource "tfe_organization_membership" "readers" {
  for_each = local.reader_emails

  email = each.value
}

resource "tfe_team_organization_members" "readers" {
  count = length(local.reader_emails) > 0 ? 1 : 0

  team_id                    = tfe_team.readers.id
  organization_membership_ids = [for m in tfe_organization_membership.readers : m.id]
}
