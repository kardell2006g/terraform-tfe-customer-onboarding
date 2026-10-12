# ---------------------------------------------------------------------------
# Project
# ---------------------------------------------------------------------------

resource "azuredevops_project" "this" {
  name               = local.project_name
  description        = "${var.company_name} (${var.environment}). Managed by Terraform."
  visibility         = var.project_visibility
  version_control    = "Git"
  work_item_template = "Agile"
}

# ---------------------------------------------------------------------------
# Read-only group
#
# Read access comes from nesting the new group inside the project's built-in
# "Readers" group. That gives read on Boards, Repos, Pipelines, Artifacts and
# Test Plans, and keeps working as Microsoft adds new permission namespaces,
# which hand-maintained per-namespace ACLs would not.
# ---------------------------------------------------------------------------

resource "azuredevops_group" "readers" {
  scope        = azuredevops_project.this.id
  display_name = local.readers_group_name
  description  = "Read-only access to ${local.project_name}. Managed by Terraform."
}

data "azuredevops_group" "project_readers" {
  project_id = azuredevops_project.this.id
  name       = "Readers"
}

resource "azuredevops_group_membership" "readers_in_project_readers" {
  group   = data.azuredevops_group.project_readers.descriptor
  members = [azuredevops_group.readers.descriptor]

  # "add" leaves anything else already in the built-in Readers group alone.
  mode = "add"
}

# ---------------------------------------------------------------------------
# Group members
#
# A user must hold an entitlement (be in the organization) before they can be
# added to a group, so each email gets one first.
# ---------------------------------------------------------------------------

resource "azuredevops_user_entitlement" "readers" {
  for_each = local.reader_emails

  principal_name       = each.value
  account_license_type = var.user_license_type
}

resource "azuredevops_group_membership" "readers" {
  count = length(local.reader_emails) > 0 ? 1 : 0

  group   = azuredevops_group.readers.descriptor
  members = [for u in azuredevops_user_entitlement.readers : u.descriptor]

  # This module owns the group, so its membership is exactly reader_emails.
  mode = "overwrite"
}
