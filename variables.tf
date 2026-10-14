# ---------------------------------------------------------------------------
# Inputs the requester fills in on the no-code form
# ---------------------------------------------------------------------------

variable "company_name" {
  description = "Customer company name. Used for the HCP Terraform project, team, variable set and AWS account names."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9 ._-]{1,29}$", var.company_name))
    error_message = "company_name must be 2-30 characters: letters, digits, spaces, '.', '_' or '-', starting with a letter or digit."
  }
}

variable "environment" {
  description = "Environment for this customer stack."
  type        = string

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, staging, prod."
  }
}

variable "reader_emails" {
  description = "Email addresses to add to the project's read-only team. Anyone not yet in the HCP Terraform organization gets an invitation."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for e in var.reader_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Every entry in reader_emails must be a valid email address."
  }
}

# ---------------------------------------------------------------------------
# Platform settings. Set these once in a variable set attached to the project
# where no-code workspaces are created, so requesters never see them.
# ---------------------------------------------------------------------------

variable "tfe_hostname" {
  description = "HCP Terraform / Terraform Enterprise hostname. Also the OIDC issuer the AWS deploy role trusts."
  type        = string
  default     = "app.terraform.io"
}

# HCP Terraform injects TFC_WORKSPACE_SLUG ("<organization>/<workspace>") into
# every run and passes it to a variable of the same name, so the organization
# comes from wherever the module runs. Nobody sets this.
variable "TFC_WORKSPACE_SLUG" {
  description = "Set automatically by HCP Terraform. Leave empty."
  type        = string
  default     = ""
}

variable "landing_zone_project_name" {
  description = "HCP Terraform project that holds every customer landing zone workspace (and so its state)."
  type        = string
  default     = "Customer Landing Zones"
}

variable "landing_zone_vcs_branch" {
  description = "Branch of the landing zone repo to run from."
  type        = string
  default     = "main"
}

variable "landing_zone_working_directory" {
  description = "Directory inside the landing zone repo that contains the landing zone configuration. Empty for the repo root."
  type        = string
  default     = ""
}

variable "github_app_installation_name" {
  description = "GitHub account or org name the HCP Terraform GitHub App is installed on, with access to the landing zone repo. Leave null to use vcs_oauth_token_id instead."
  type        = string
  default     = null
}

variable "vcs_oauth_token_id" {
  description = "OAuth token ID (ot-...) of an HCP Terraform GitHub OAuth VCS provider. Only used when github_app_installation_name is null (e.g. Terraform Enterprise without the GitHub App)."
  type        = string
  default     = null

  validation {
    condition     = (var.github_app_installation_name == null) != (var.vcs_oauth_token_id == null)
    error_message = "Set exactly one of github_app_installation_name or vcs_oauth_token_id."
  }
}

variable "landing_zone_variable_set_names" {
  description = "Variable sets to attach to the landing zone workspace, e.g. the one holding AWS management-account credentials."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "Home AWS region for the customer landing zone."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_root_mailbox" {
  description = "Mailbox that receives every new AWS account's root email. Each account gets <user>+aws<random>@<domain>, which plus-addressing delivers here. Set once: changing it later changes every account's email."
  type        = string
  default     = "adam.kardell@hashicorp.com"

  validation {
    condition     = can(regex("^[^@+\\s]+@[^@\\s]+\\.[^@\\s]+$", var.aws_account_root_mailbox))
    error_message = "aws_account_root_mailbox must be a plain address (no '+' tag), e.g. adam.kardell@hashicorp.com."
  }
}

variable "aws_dynamic_credentials" {
  description = "Create a per-customer deploy role in the shared AWS account and give the customer project HCP Terraform dynamic credentials for it. Needs an IAM OIDC provider for HCP Terraform in that account."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the landing zone VPC."
  type        = string
  default     = "10.0.0.0/16"
}
