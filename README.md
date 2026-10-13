# Customer onboarding (Terraform no-code)

Requesters fill in **company_name**, **environment** and **reader_emails**. One
apply then, all in HCP Terraform:

1. Creates the project `<company_name> <environment>` for the customer's
   workspaces.
2. Creates the team `<company>-<env>-readers` with **read** access to that
   project.
3. Adds every email in `reader_emails` to the team, inviting anyone who isn't
   in the organization yet.
4. Creates the workspace `lz-<company>-<env>` in the **Customer Landing Zones**
   project, sets its variables and runs it. That workspace applies the
   [customer-landing-zone](https://github.com/kardell2006g/customer-landing-zone)
   repo: a new AWS account in your Organization plus its baseline. **Its state
   lives in that workspace**, not in the no-code workspace.
5. Creates the variable set `<company>-<env>-aws-landing-zone` from the landing
   zone outputs and attaches it to the customer project.

## Two stacks, two states

| Stack | Runs in | State |
|---|---|---|
| `terraform-tfe-customer-onboarding` (this module) | The no-code workspace the requester provisions | Customer project, team, memberships, variable set, the landing zone *workspace* |
| `customer-landing-zone` | `lz-<company>-<env>` in project **Customer Landing Zones** | AWS account, security baseline, VPC, OIDC deploy role |

The handoff uses `tfe_workspace_run` (apply on create, destroy on destroy) and
`data "tfe_outputs"`. Destroying the no-code workspace destroys the landing
zone first, which **closes the AWS account** (`close_on_deletion = true`,
recoverable for 90 days).

## What the landing zone builds

- `aws_organizations_account` in `aws_organizational_unit_id`, or the org root if that is unset
- EBS encryption by default, account-level S3 public access block, IAM password
  policy, IAM Access Analyzer
- VPC with public and private /20 subnets across 2 AZs, IGW, one NAT gateway,
  locked-down default security group
- IAM OIDC provider for HCP Terraform and a `tfc-deploy` role that only
  workspaces in the customer's project can assume

## Variable set contents

Attached to the customer project, so every workspace created there can deploy
to the customer's AWS account with no extra setup:

| Key | Category | Value |
|---|---|---|
| `TFC_AWS_PROVIDER_AUTH` | env | `true` (turns on dynamic credentials) |
| `TFC_AWS_RUN_ROLE_ARN` | env | the `tfc-deploy` role |
| `AWS_REGION` | env | landing zone region |
| `company_name`, `environment`, `aws_account_id`, `aws_region`, `vpc_id` | terraform | strings |
| `public_subnet_ids`, `private_subnet_ids` | terraform (HCL) | lists |

Nothing is secret: runs get short-lived AWS credentials through OIDC. A
workspace that doesn't declare the Terraform variables just gets an
"undeclared variable" warning.

## One-time setup

1. **GitHub repos.** Done:
   [terraform-tfe-customer-onboarding](https://github.com/kardell2006g/terraform-tfe-customer-onboarding)
   and [customer-landing-zone](https://github.com/kardell2006g/customer-landing-zone).
   Protect `main` on `customer-landing-zone`; every merge queues a plan in
   every customer's `lz-*` workspace. Publishing a new module version needs a
   semver tag (`git tag v1.5.0 && git push --tags`).
2. **Connect GitHub.** Organization settings → VCS providers → GitHub App,
   installed on `kardell2006g` with access to both repos.
3. **Projects.** Create `Customer Landing Zones`, plus a project for the
   no-code workspaces (e.g. `Customer Onboarding`).
4. **Variable set: AWS** (e.g. `aws-org-management`) with management-account
   credentials allowed to call `organizations:CreateAccount` and assume
   `OrganizationAccountAccessRole`. Dynamic credentials preferred. Don't make
   it global; the module attaches it to each landing zone workspace via
   `landing_zone_variable_set_names`.
5. **Team token.** Create a team (e.g. `customer-onboarding`) with
   organization permissions **Manage projects**, **Manage teams**,
   **Manage membership** and **Manage variable sets**, and **Admin** on
   `Customer Landing Zones`. Generate its team token. An organization token
   won't work: it can't start runs.
6. **Variable set: onboarding platform**, attached to the onboarding project:

   | Key | Category | Example |
   |---|---|---|
   | `TFE_TOKEN` | env, sensitive | the team token from step 5 |
   | `github_app_installation_name` | terraform | `kardell2006g` |
   | `landing_zone_variable_set_names` | terraform, HCL | `["aws-org-management"]` |
   | `aws_organizational_unit_id` | terraform | `ou-ab12-cd34ef56` (optional; omit for the org root) |

   The HCP Terraform organization isn't set anywhere: the module reads it
   from `TFC_WORKSPACE_SLUG`, which HCP Terraform injects into every run.
   For a local run, export `TFE_ORGANIZATION` instead. The landing zone repo
   is fixed to `kardell2006g/customer-landing-zone` in `main.tf`.

7. **Publish.** Registry → Publish → Module → GitHub → pick
   `terraform-tfe-customer-onboarding`, tick *Add module to no-code provision
   allowlist*. Pin `environment` to dev / test / staging / prod.

## Things to know

- **AWS root emails.** Each account's root email is
  `adam.kardell+aws<5 random digits>@hashicorp.com` (from
  `aws_account_root_mailbox`), so root password resets and AWS notices for
  every customer account land in that one inbox. The number is generated once
  per customer and kept in state. Changing `aws_account_root_mailbox` later
  changes every account's email on its next apply.
- **Account names** are `<company>-<env>-aws<number>` (e.g.
  `acme-corp-prod-aws48213`), using the same number as the root email.
  VPC, subnet and other resource names in the account start with it too.
- **Tracing an email to its workspace.** The `+aws<number>` part is the
  landing zone workspace's `aws-email-tag` tag (search workspaces by it), and
  the full email is in the workspace description. In the other direction,
  the AWS account and everything in it carry a `TFC Workspace` tag with
  `<organization>/lz-<company>-<env>`.

- **Removing an email** removes the user's whole organization membership,
  not just their team seat. If people belong to several customers, manage
  memberships elsewhere and switch this module to look them up
  (`data "tfe_organization_membership"`).
- Invited users only appear in the team after they accept the invitation.
- Every new member takes a seat on your HCP Terraform plan.
- **Read** project access lets the team view workspaces, runs, non-sensitive
  variables and state, but not queue runs or change anything. Use `custom`
  access to narrow or widen that.
- `tfe_workspace_run` only applies on create. Later changes to
  `customer-landing-zone` come in as VCS runs on each `lz-*` workspace and
  wait for approval.
- First apply of the landing zone configures the `aws.account` provider with an
  unknown role ARN at plan time. This works for creates; if the plan ever errors
  on it, apply with `-target=time_sleep.account_ready` once, then apply normally.
- The deploy role trusts the project by name. Renaming the customer project
  breaks the trust until the landing zone is re-applied.
- Org-wide controls (CloudTrail, GuardDuty, Security Hub, Config, SCPs) belong
  at the AWS Organization level, not per account. They aren't in this module.
- The deploy role gets `PowerUserAccess` (no IAM). Change
  `deploy_role_policy_arns` if workspaces need to manage IAM.
