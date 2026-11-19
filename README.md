# guardrails-demo

AI assistants write Terraform quickly and get security details wrong quietly.
This repo shows the control that sits between "AI wrote it" and "it is applied":
a pull-request gate made of static scanning, a plan, and policy-as-code.

```
AI draft PR -> Trivy config scan -> terraform plan -> Conftest (OPA) policy -> human review -> apply
```

## Layout

| Path | Purpose |
| --- | --- |
| `terraform/ai-draft/` | A realistic first draft with four mistakes: world-open SSH, `Action: "*"`, unencrypted DB, hard-coded password |
| `terraform/good/` | The reviewed version of the same stack. Passes every rule |
| `policy/terraform.rego` | Rego rules run against the plan JSON |
| `.github/workflows/guardrails.yml` | Runs both directories; `ai-draft` is expected to fail |

## Run locally

```bash
cd terraform/ai-draft
terraform init -backend=false
terraform plan -refresh=false -out=plan.out
terraform show -json plan.out > plan.json
conftest test plan.json --policy ../../policy   # expect failures
```

Repeat in `terraform/good` and the policy gate should pass.

## Verified results

Run locally with Terraform 1.9.8 and Conftest 0.56.0 (offline plan, dummy credentials):

| Directory | Result | Violations |
| --- | --- | --- |
| `terraform/ai-draft` | **7 failures** | world-open SSH, wildcard IAM action, unencrypted DB, literal DB password, missing `owner` tag on 3 resources |
| `terraform/good` | **6 of 6 passed** | none |

Writing the policy itself exposed three bugs in my first version: a Rego set
declared as an object, a tag rule that never fired because `tags_all` is unknown
at plan time, and a password rule that missed literals because the provider marks
the attribute sensitive either way. A gate is only trusted once you have seen it fail.

## Findings log

Fill this in as you use it. Evidence beats claims.

| Date | Assistant / model | Prompt | Mistake it made | Rule that caught it |
| --- | --- | --- | --- | --- |
| | | | | |

## Next steps

- Add Infracost to comment the monthly cost delta on the PR.
- Add a required reviewer rule so policy passing never replaces human approval.
- Add more rules as real mistakes show up in the findings log.
