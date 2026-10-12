output "project_name" {
  description = "Azure DevOps project name."
  value       = azuredevops_project.this.name
}

output "project_id" {
  description = "Azure DevOps project ID."
  value       = azuredevops_project.this.id
}

output "readers_group_name" {
  description = "Read-only group created in the project."
  value       = azuredevops_group.readers.display_name
}

output "variable_group_name" {
  description = "Variable group holding the landing zone settings."
  value       = azuredevops_variable_group.this.name
}

output "aws_account_id" {
  description = "AWS account created for the landing zone."
  value       = local.lz["account_id"]
}

output "aws_deploy_role_arn" {
  description = "IAM role Azure DevOps pipelines assume (via OIDC) to deploy into the account."
  value       = local.lz["deploy_role_arn"]
}

output "aws_service_connection_name" {
  description = "Name the project's AWS service connection must have for the OIDC trust to match."
  value       = local.aws_service_connection
}

output "landing_zone_workspace" {
  description = "HCP Terraform workspace (in the Customer Landing Zones project) that holds the landing zone state."
  value       = tfe_workspace.landing_zone.name
}
