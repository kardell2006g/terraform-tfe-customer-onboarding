terraform {
  # 1.9+ for the validation that compares two variables.
  required_version = ">= 1.9.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.64, < 1.0"
    }
  }
}

# No-code modules run as the root module of their workspace, so the provider
# is configured here. TFE_TOKEN (env, sensitive) comes from a variable set on
# the no-code workspace's project, never from module variables. It must be a
# team token, not an organization token (those can't start runs), for a team
# that can manage projects, teams, membership and variable sets.
provider "tfe" {
  hostname     = var.tfe_hostname
  organization = local.run_organization
}
