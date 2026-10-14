# ---------------------------------------------------------------------------
# Drift notifications to the customer contact.
#
# HCP Terraform attaches notifications to workspaces, not projects, and its
# email notifications go to organization members by user ID (sending to raw
# addresses is Terraform Enterprise only). So this targets the landing zone
# workspace, the one this module owns, and emails customer_email's user.
#
# Auto-destroy reminders only fire on workspaces that auto-destroy. The
# landing zone doesn't, and the auto-destroying workspaces in the customer's
# project are created later by the customer, so they need their own
# notification for workspace:auto_destroy_reminder.
# ---------------------------------------------------------------------------

resource "tfe_notification_configuration" "customer" {
  count = var.enable_notifications && var.enable_drift_detection ? 1 : 0

  name             = "${local.name}-drift"
  enabled          = true
  destination_type = "email"
  workspace_id     = tfe_workspace.landing_zone.id
  email_user_ids   = [tfe_organization_membership.members[local.customer_email].user_id]
  triggers         = ["assessment:drifted"]
}
