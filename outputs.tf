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
  description = "Variable set attached to the project with the landing zone settings and AWS dynamic credentials."
  value       = tfe_variable_set.customer.name
}

output "aws_account_id" {
  description = "AWS account created for the landing zone."
  value       = local.lz["account_id"]
}

output "aws_deploy_role_arn" {
  description = "IAM role workspaces in the customer project assume via HCP Terraform dynamic credentials."
  value       = local.lz["deploy_role_arn"]
}

output "landing_zone_workspace" {
  description = "HCP Terraform workspace (in the Customer Landing Zones project) that holds the landing zone state."
  value       = tfe_workspace.landing_zone.name
}
