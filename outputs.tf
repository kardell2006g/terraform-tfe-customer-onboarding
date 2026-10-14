output "project_name" {
  description = "HCP Terraform project for the customer's workspaces."
  value       = tfe_project.customer.name
}

output "project_id" {
  description = "HCP Terraform project ID."
  value       = tfe_project.customer.id
}

output "readers_team_name" {
  description = "Team with read access to the project."
  value       = tfe_team.readers.name
}

output "variable_set_name" {
  description = "Variable set attached to the project with the landing zone values."
  value       = tfe_variable_set.customer.name
}

output "aws_account_id" {
  description = "Dummy customer AWS account ID (starts with 0000)."
  value       = local.lz["account_id"]
}

output "aws_deploy_role_arn" {
  description = "Per-customer deploy role in the shared AWS account, or null when aws_dynamic_credentials is false."
  # tfe_outputs drops null outputs, so the key is missing when disabled.
  value = lookup(local.lz, "deploy_role_arn", null)
}

output "aws_deployment_account_id" {
  description = "Real AWS account the customer's network and deploy role are in."
  value       = local.lz["deployment_account_id"]
}

output "landing_zone_workspace" {
  description = "HCP Terraform workspace (in the Customer Landing Zones project) that holds the landing zone state."
  value       = tfe_workspace.landing_zone.name
}

output "aws_account_email" {
  description = "Root email of the customer AWS account. Its +aws<number> tag is also the landing zone workspace's aws-email-tag."
  value       = local.aws_account_email
}

output "aws_account_name" {
  description = "Name of the customer AWS account (<company>-<environment>-aws<number>)."
  value       = local.aws_account_name
}

output "aws_account_is_dummy" {
  description = "True while the customer AWS account is a dummy. Its network and deploy role are real, in the shared account."
  value       = local.lz["is_dummy"]
}

output "auto_destroy_after" {
  description = "Inactivity period after which the customer project's workspaces and the landing zone are destroyed. Null outside test."
  value       = local.auto_destroy_duration
}
