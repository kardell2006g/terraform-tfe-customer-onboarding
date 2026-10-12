# Customer onboarding (Terraform no-code)

Requesters fill in **company_name**, **environment** and **reader_emails**. One
apply then:

1. Creates the Azure DevOps project `<company_name> <environment>`.
2. Creates the group `<project> Readers` and nests it in the project's built-in
   **Readers** group (read on Boards, Repos, Pipelines, Artifacts, Test Plans).
3. Adds every email in `reader_emails` to the org (if needed) and to that group.
4. Creates the HCP Terraform workspace `lz-<company>-<env>` in the
   **Customer Landing Zones** project, sets its variables and runs it. That
   workspace applies `../customer-landing-zone`: a new AWS account in your
   Organization plus its baseline. **Its state lives in that workspace**, not
   in the no-code workspace.
5. Reads the landing zone outputs and creates the variable group
   `<company>-<env>-aws-landing-zone` in the project.

## Two stacks, two states

| Stack | Runs in | State |
|---|---|---|
| `customer-onboarding/` (this module) | The no-code workspace the requester provisions | ADO project, group, members, variable group, the landing zone *workspace* |
| `customer-landing-zone/` | `lz-<company>-<env>` in project **Customer Landing Zones** | AWS account, security baseline, VPC, OIDC deploy role |

The handoff uses `tfe_workspace_run` (apply on create, destroy on destroy) and
`data "tfe_outputs"`. Destroying the no-code workspace destroys the landing
zone first, which **closes the AWS account** (`close_on_deletion = true`,
recoverable for 90 days).

## What the landing zone builds

- `aws_organizations_account` in the OU mapped from `environment`
- EBS encryption by default, account-level S3 public access block, IAM password
  policy, IAM Access Analyzer
- VPC with public and private /20 subnets across 2 AZs, IGW, one NAT gateway,
  locked-down default security group
- IAM OIDC provider for your Azure DevOps org and an `azdo-deploy` role that only
  the service connection `aws-<company>-<env>` in the new project can assume

## Variable group contents

`COMPANY_NAME`, `ENVIRONMENT`, `AWS_ACCOUNT_ID`, `AWS_REGION`,
`AWS_DEPLOY_ROLE_ARN`, `AWS_SERVICE_CONNECTION`, `AWS_VPC_ID`,
`AWS_PUBLIC_SUBNET_IDS`, `AWS_PRIVATE_SUBNET_IDS` (comma-separated),
`TFC_LANDING_ZONE_WORKSPACE`. Nothing secret: pipelines use OIDC, not keys.

## One-time setup

1. **GitHub repos** (private, in your GitHub org):
   - `terraform-azuredevops-customer-onboarding`: contents of
     `customer-onboarding/` at the repo root. The registry requires the
     `terraform-<provider>-<name>` name and the module at the root.
   - `customer-landing-zone`: contents of `customer-landing-zone/`. If you
     keep it in a subfolder of another repo instead, set
     `landing_zone_working_directory`.
   - Protect `main` and require PR review on `customer-landing-zone`: every
     merge queues a plan in every customer's `lz-*` workspace.
   - Publishing a registry module version needs a semver tag:
     `git tag v1.0.0 && git push --tags`.
2. **Connect GitHub to HCP Terraform.** Organization settings → VCS
   providers → GitHub App, and install the app on your GitHub org with access
   to both repos. (On Terraform Enterprise without the app, add a GitHub OAuth
   VCS provider and use `vcs_oauth_token_id` instead.)
3. **HCP Terraform project** named `Customer Landing Zones`.
4. **Variable set: AWS** (e.g. `aws-org-management`), with management-account
   credentials allowed to call `organizations:CreateAccount` and assume
   `OrganizationAccountAccessRole`. Dynamic provider credentials preferred.
   Don't make it global; the module attaches it to each landing zone workspace
   via `landing_zone_variable_set_names`.
5. **Variable set: onboarding platform**, attached to the project where
   no-code workspaces are created:

   | Key | Category | Example |
   |---|---|---|
   | `AZDO_ORG_SERVICE_URL` | env | `https://dev.azure.com/contoso` |
   | `AZDO_PERSONAL_ACCESS_TOKEN` | env, sensitive | PAT: Project & Team, Graph, Member Entitlement Management, Variable Groups (read/write/manage) |
   | `TFE_TOKEN` | env, sensitive | Team token with admin on Customer Landing Zones |
   | `tfe_organization` | terraform | `contoso` |
   | `landing_zone_vcs_repo` | terraform | `contoso/customer-landing-zone` |
   | `github_app_installation_name` | terraform | `contoso` (GitHub org the app is installed on) |
   | `landing_zone_variable_set_names` | terraform, HCL | `["aws-org-management"]` |
   | `aws_account_email_domain` | terraform | `contoso.com` |
   | `aws_organizational_unit_ids` | terraform, HCL | `{ dev = "ou-..", test = "ou-..", staging = "ou-..", prod = "ou-.." }` |
   | `azdo_organization_name` | terraform | `contoso` |
   | `azdo_organization_id` | terraform | ADO org GUID |

6. **Publish** in the private registry (Publish → Module → GitHub → pick the repo) and tick *Add module to no-code
   provision allowlist*. Pin `environment` to dev / test / staging / prod.

## After provisioning

Create an AWS service connection in the new project named exactly as the
`aws_service_connection_name` output, using OIDC with the
`aws_deploy_role_arn` output. The OIDC trust only matches that name.

## Things to know

- **Removing an email** removes the user from the group and also deletes
  their org entitlement, which drops them from the whole Azure DevOps org.
  If users are shared across customers, manage entitlements elsewhere and
  switch this module to look users up instead.
- `basic` licences cost money; `stakeholder` is free but can't read Repos.
- `tfe_workspace_run` only applies on create. Later changes to
  `customer-landing-zone` come in as VCS runs on each `lz-*` workspace and
  wait for approval.
- First apply of the landing zone configures the `aws.account` provider with an
  unknown role ARN at plan time. This works for creates; if the plan ever errors
  on it, apply with `-target=time_sleep.account_ready` once, then apply normally.
- Org-wide controls (CloudTrail, GuardDuty, Security Hub, Config, SCPs) belong
  at the Organization level, not per account. They aren't in this module.
- The deploy role gets `PowerUserAccess` (no IAM). Change
  `deploy_role_policy_arns` if pipelines need to manage IAM.
