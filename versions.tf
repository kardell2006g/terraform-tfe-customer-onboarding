terraform {
  # 1.9+ for the validation that compares two variables.
  required_version = ">= 1.9.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.4, < 2.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.64, < 1.0"
    }
  }
}

# No-code modules run as the root module of their workspace, so providers are
# configured here. Credentials come from a variable set on the no-code
# workspace's project, never from module variables:
#   azuredevops: AZDO_ORG_SERVICE_URL, AZDO_PERSONAL_ACCESS_TOKEN (env)
#   tfe:         TFE_TOKEN (env) - a team token that can manage workspaces in
#                the "Customer Landing Zones" project
provider "azuredevops" {}

provider "tfe" {
  organization = var.tfe_organization
}
