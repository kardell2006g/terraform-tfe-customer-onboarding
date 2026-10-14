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
   repo. **Its state lives in that workspace**, not in the no-code workspace.
5. Creates the variable set `<company>-<env>-aws-landing-zone` from the landing
   zone outputs and attaches it to the customer project.

## The landing zone is a dummy

**Nothing is created in AWS.** The landing zone has no AWS provider and needs
no AWS credentials. It generates placeholder values shaped like a real landing
zone's and keeps them in its workspace state, so they're stable across runs:

| Output | Example |
|---|---|
| `account_id` | `000048213907` (always starts with `0000`) |
| `account_name` | `acme-corp-prod-aws48213` |
| `account_email` | `adam.kardell+aws48213@hashicorp.com` |
| `deploy_role_arn` | `arn:aws:iam::000048213907:role/tfc-deploy` |
| `vpc_id`, `public_subnet_ids`, `private_subnet_ids` | `vpc-…`, `subnet-…` (17 hex characters) |
| `is_dummy` | `true` |

The real implementation (AWS account, security baseline, VPC, OIDC deploy
role) is in the landing zone repo's history at commit `80f34fc`. Restoring it
also means adding `TFC_AWS_PROVIDER_AUTH` and `TFC_AWS_RUN_ROLE_ARN` back to
the customer variable set (see `variable_set.tf`).

## Two stacks, two states

| Stack | Runs in | State |
|---|---|---|
| `terraform-tfe-customer-onboarding` (this module) | The no-code workspace the requester provisions | Customer project, team, memberships, variable set, the landing zone *workspace* |
| `customer-landing-zone` | `lz-<company>-<env>` in project **Customer Landing Zones** | Dummy account values |

The handoff uses `tfe_workspace_run` (apply on create, destroy on destroy) and
`data "tfe_outputs"`. Destroying the no-code workspace destroys the landing
zone first, then deletes its workspace.

## Variable set contents

Attached to the customer project, so every workspace there sees the landing
zone values:

| Key | Category | Value |
|---|---|---|
| `AWS_REGION` | env | landing zone region |
| `company_name`, `environment`, `aws_account_id`, `aws_account_name`, `aws_region`, `aws_deploy_role_arn`, `vpc_id` | terraform | strings |
| `aws_account_is_dummy` | terraform (HCL) | `true` |
| `public_subnet_ids`, `private_subnet_ids` | terraform (HCL) | lists |

AWS dynamic credentials are deliberately **not** set: with a dummy role ARN,
every AWS provider in the project would fail to authenticate. A workspace that
doesn't declare these Terraform variables just gets an "undeclared variable"
warning.

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
4. **Team token.** Create a team (e.g. `customer-onboarding`) with
   organization permissions **Manage projects**, **Manage teams**,
   **Manage membership** and **Manage variable sets**, and **Admin** on
   `Customer Landing Zones`. Generate its team token. An organization token
   won't work: it can't start runs.
5. **Variable set: onboarding platform**, attached to the onboarding project:

   | Key | Category | Example |
   |---|---|---|
   | `TFE_TOKEN` | env, sensitive | the team token from step 4 |
   | `github_app_installation_name` | terraform | `kardell2006g` |

   The HCP Terraform organization isn't set anywhere: the module reads it
   from `TFC_WORKSPACE_SLUG`, which HCP Terraform injects into every run.
   For a local run, export `TFE_ORGANIZATION` instead. The landing zone repo
   is fixed to `kardell2006g/customer-landing-zone` in `main.tf`. No AWS
   variable set is needed while the landing zone is a dummy.

6. **Publish.** Registry → Publish → Module → GitHub → pick
   `terraform-tfe-customer-onboarding`, tick *Add module to no-code provision
   allowlist*. Pin `environment` to dev / test / staging / prod.

## Things to know

- **Account names and emails.** Names are `<company>-<env>-aws<number>` and
  root emails `adam.kardell+aws<number>@hashicorp.com` (from
  `aws_account_root_mailbox`), with the same 5-digit number, generated once
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
- `aws_organizational_unit_id`, `aws_region`, `vpc_cidr` and
  `landing_zone_variable_set_names` are still accepted but have no effect on
  the dummy landing zone, apart from `aws_region` being reported back.
