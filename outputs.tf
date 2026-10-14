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
  description = "AWS account ID from the landing zone. Currently a dummy starting with 0000."
  value       = local.lz["account_id"]
}

output "aws_deploy_role_arn" {
  description = "Deploy role ARN from the landing zone. Currently a dummy that nothing can assume."
  value       = local.lz["deploy_role_arn"]
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
  description = "True while the landing zone generates placeholder values instead of creating a real AWS account."
  value       = local.lz["is_dummy"]
}
