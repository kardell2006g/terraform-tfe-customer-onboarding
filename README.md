# Customer onboarding (Terraform no-code)

Requesters fill in **company_name**, **environment**, **customer_email** and
**reader_emails**. One
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
   repo. **Its state lives in that workspace**, not in the no-code workspace.
5. Creates the variable set `<company>-<env>-aws-landing-zone` from the landing
   zone outputs and attaches it to the customer project.

## Dummy account, real network

**No AWS account is created.** The customer's account is a dummy: its ID is
generated (always starting with `0000`) and kept in the landing zone state.
The customer's **network and deploy role are real**, built in the shared AWS
account that your **global variable set** gives credentials for.

| Landing zone output | Real? | Example |
|---|---|---|
| `account_id` | dummy | `000048213907` |
| `account_name` | dummy, also the prefix of every real resource name | `acme-corp-prod-aws48213` |
| `account_email` | dummy, never used | `jane.doe+aws48213@example.com` |
| `deployment_account_id` | real: the shared account | `009071937843` |
| `vpc_id`, `public_subnet_ids`, `private_subnet_ids` | real | `acme-corp-prod-aws48213-vpc` and its subnets |
| `deploy_role_arn` | real (if `aws_dynamic_credentials`) | `arn:aws:iam::009071937843:role/tfc-deploy-acme-corp-prod-aws48213` |
| `is_dummy` | | `true` |

Per customer, in the shared account:

- VPC (`vpc_cidr`, default `10.0.0.0/16`) with public and private /20 subnets
  across 2 AZs, internet gateway, route tables, and a rule-less default
  security group. NAT gateway off by default (`enable_nat_gateway` in the
  landing zone, about $32/month each).
- With `aws_dynamic_credentials` (default `true`): the IAM role
  `tfc-deploy-<account name>` with `PowerUserAccess`, which only workspaces
  in the customer's HCP Terraform project can assume. It reuses the account's
  existing HCP Terraform OIDC provider (one per account), so that provider
  must already exist.
- Every resource is tagged `Company`, `Environment`, `Customer Account` and
  `TFC Workspace`.

Account-wide settings (EBS default encryption, S3 public access block,
password policy) are left alone: they're one-per-account, so per-customer
workspaces would fight over them.

The original real-account implementation is in the landing zone repo's
history at commit `80f34fc`.

## Test environments, drift and notifications

- **Auto-destroy (`environment = "test"` only).** The customer project gets
  `auto_destroy_activity_duration = test_auto_destroy_duration` (default
  `7d`), so workspaces the customer creates in it are destroyed after 7 days
  without a run, unless they override it. The landing zone workspace and the
  Customer Landing Zones project never auto-destroy.
- **Drift detection.** `assessments_enabled` on the landing zone workspace
  (`enable_drift_detection`, default `true`). Needs an HCP Terraform plan that
  includes health assessments.
- **Drift notifications to `customer_email`** on the landing zone workspace
  (`enable_notifications`, default `true`). HCP Terraform only supports
  notifications on workspaces, not projects, and only emails organization
  members, so `customer_email` is invited to the organization. Auto-destroy
  reminders need a notification on each auto-destroying workspace, i.e. the
  ones the customer creates in their project, so they aren't set up here.

## Two stacks, two states

| Stack | Runs in | State |
|---|---|---|
| `terraform-tfe-customer-onboarding` (this module) | The no-code workspace the requester provisions | Customer project, team, memberships, variable set, the landing zone *workspace* |
| `customer-landing-zone` | `lz-<company>-<env>` in project **Customer Landing Zones** | Dummy account ID, customer VPC and deploy role |

The handoff uses `tfe_workspace_run` (apply on create, destroy on destroy) and
`data "tfe_outputs"`. Destroying the no-code workspace destroys the customer's
VPC and role first, then deletes the landing zone workspace. The workspace has
`force_delete = true`, so it's deleted even if that destroy left resources in
its state; anything left behind is orphaned in AWS and can be found by its
`TFC Workspace` tag. The deploy role has `force_detach_policies = true`, so
policies attached outside Terraform don't block its deletion.

## Variable set contents

Attached to the customer project:

| Key | Category | Value |
|---|---|---|
| `AWS_REGION` | env | landing zone region |
| `TFC_AWS_PROVIDER_AUTH`, `TFC_AWS_RUN_ROLE_ARN` | env | dynamic credentials for the customer's deploy role (only with `aws_dynamic_credentials`) |
| `company_name`, `environment`, `aws_account_id`, `aws_account_name`, `aws_deployment_account_id`, `aws_region`, `vpc_id` | terraform | strings |
| `aws_deploy_role_arn` | terraform | role ARN (only with `aws_dynamic_credentials`) |
| `aws_account_is_dummy` | terraform (HCL) | `true` |
| `public_subnet_ids`, `private_subnet_ids` | terraform (HCL) | lists |

Project variable sets take precedence over global ones, so with
`aws_dynamic_credentials` the customer's workspaces use their own role instead
of the global credentials. A workspace that doesn't declare the Terraform
variables just gets an "undeclared variable" warning.

## One-time setup

1. **GitHub repos.** Done:
   [terraform-tfe-customer-onboarding](https://github.com/kardell2006g/terraform-tfe-customer-onboarding)
   and [customer-landing-zone](https://github.com/kardell2006g/customer-landing-zone).
   Protect `main` on `customer-landing-zone`; every merge queues a plan in
   every customer's `lz-*` workspace. Publishing a new module version needs a
   semver tag (`git tag v1.6.0 && git push --tags`).
2. **Connect GitHub.** Organization settings → VCS providers → GitHub App,
   installed on `kardell2006g` with access to both repos.
3. **Projects.** Create `Customer Landing Zones`, plus a project for the
   no-code workspaces (e.g. `Customer Onboarding`).
4. **Global variable set: AWS.** Credentials for the shared AWS account the
   customer networks go into. Dynamic credentials are recommended:
   `TFC_AWS_PROVIDER_AUTH = true` and `TFC_AWS_RUN_ROLE_ARN` for a role that
   can manage VPCs, subnets, gateways and route tables, create and delete
   `tfc-deploy-*` IAM roles, and attach policies to them. That setup also
   creates the HCP Terraform OIDC provider the customer deploy roles reuse.
   Because it's global, every workspace in the organization gets these
   credentials unless a project or workspace overrides them.
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

   The HCP Terraform organization isn't set anywhere: the module reads it
   from `TFC_WORKSPACE_SLUG`, which HCP Terraform injects into every run.
   For a local run, export `TFE_ORGANIZATION` instead. The landing zone repo
   is fixed to `kardell2006g/customer-landing-zone` in `main.tf`.

7. **Publish.** Registry → Publish → Module → GitHub → pick
   `terraform-tfe-customer-onboarding`, tick *Add module to no-code provision
   allowlist*. Pin `environment` to dev / test / staging / prod.

## Things to know

- **`customer_email` must accept the HCP Terraform invitation**, or already
  have an HCP Terraform account, before notifications can reach them. If the
  address has no HCP Terraform user yet, creating the notification may fail;
  set `enable_notifications = false` and turn it on after they join. They
  don't get project access unless they're also in `reader_emails`.
- **Account names and emails.** Names are `<company>-<env>-aws<number>` and
  root emails `<customer_email user>+aws<number>@<domain>` (e.g.
  `jane.doe+aws48213@example.com`), with the same 5-digit number, generated once
  per customer and kept in state. No email is ever sent while the landing
  zone is a dummy.
- **Tracing a number to its workspace.** The `aws<number>` part is the
  landing zone workspace's `aws-email-tag` tag (search workspaces by it), and
  the full email is in the workspace description.
- **Removing an email** from `reader_emails` removes the user's whole
  organization membership, not just their team seat. If people belong to
  several customers, manage memberships elsewhere and switch this module to
  look them up (`data "tfe_organization_membership"`).
- Invited users only appear in the team after they accept the invitation.
- Every new member takes a seat on your HCP Terraform plan.
- **Read** project access lets the team view workspaces, runs, non-sensitive
  variables and state, but not queue runs or change anything. Use `custom`
  access to narrow or widen that.
- `tfe_workspace_run` only applies on create. Later changes to
  `customer-landing-zone` come in as VCS runs on each `lz-*` workspace and
  wait for approval.
- Every customer gets `vpc_cidr` (default `10.0.0.0/16`). Overlapping VPCs in
  one account are fine, but they can't be peered with each other. Watch the
  regional VPC limit (5 per region by default) in the shared account.
- `landing_zone_variable_set_names` is optional now that AWS credentials come
  from the global variable set.
