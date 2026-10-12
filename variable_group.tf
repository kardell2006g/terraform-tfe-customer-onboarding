# ---------------------------------------------------------------------------
# Variable group: everything a pipeline needs to deploy into the landing zone.
# Nothing here is secret. Pipelines authenticate to AWS through the OIDC
# deploy role, not stored keys.
# ---------------------------------------------------------------------------

locals {
  variable_group_vars = {
    COMPANY_NAME               = var.company_name
    ENVIRONMENT                = var.environment
    AWS_ACCOUNT_ID             = local.lz["account_id"]
    AWS_REGION                 = local.lz["aws_region"]
    AWS_DEPLOY_ROLE_ARN        = local.lz["deploy_role_arn"]
    AWS_SERVICE_CONNECTION     = local.aws_service_connection
    AWS_VPC_ID                 = local.lz["vpc_id"]
    AWS_PUBLIC_SUBNET_IDS      = join(",", local.lz["public_subnet_ids"])
    AWS_PRIVATE_SUBNET_IDS     = join(",", local.lz["private_subnet_ids"])
    TFC_LANDING_ZONE_WORKSPACE = tfe_workspace.landing_zone.name
  }
}

resource "azuredevops_variable_group" "this" {
  project_id   = azuredevops_project.this.id
  name         = local.variable_group_name
  description  = "AWS landing zone settings for ${var.company_name} (${var.environment}). Managed by Terraform; manual edits are overwritten."
  allow_access = false

  dynamic "variable" {
    for_each = local.variable_group_vars

    content {
      name  = variable.key
      value = variable.value
    }
  }
}
