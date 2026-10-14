# ---------------------------------------------------------------------------
# Notifications to the customer contact.
#
# HCP Terraform attaches notifications to workspaces, not projects, and its
# email notifications go to organization members by user ID (sending to raw
# addresses is Terraform Enterprise only). So this targets the landing zone
# workspace, the one this module owns, and emails customer_email's user.
# Workspaces the customer creates in their project need their own.
# ---------------------------------------------------------------------------

locals {
  notification_triggers = concat(
    local.is_test ? ["workspace:auto_destroy_reminder", "workspace:auto_destroy_run_results"] : [],
    var.enable_drift_detection ? ["assessment:drifted"] : [],
  )
}

resource "tfe_notification_configuration" "customer" {
  count = var.enable_notifications && length(local.notification_triggers) > 0 ? 1 : 0

  name             = "${local.name}-customer-alerts"
  enabled          = true
  destination_type = "email"
  workspace_id     = tfe_workspace.landing_zone.id
  email_user_ids   = [tfe_organization_membership.members[local.customer_email].user_id]
  triggers         = local.notification_triggers
}
