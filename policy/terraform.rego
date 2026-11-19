package main

# Run against `terraform show -json plan.out` with: conftest test plan.json
# Each rule encodes a mistake that AI-generated Terraform commonly makes.

import rego.v1

resources contains r if {
	r := input.resource_changes[_]
	r.change.actions[_] != "delete"
}

deny contains msg if {
	r := resources[_]
	r.type == "aws_security_group_rule"
	r.change.after.type == "ingress"
	r.change.after.cidr_blocks[_] == "0.0.0.0/0"
	r.change.after.from_port != 443
	msg := sprintf("%s: ingress open to the world on port %v", [r.address, r.change.after.from_port])
}

deny contains msg if {
	r := resources[_]
	r.type == "aws_s3_bucket_public_access_block"
	some k in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	r.change.after[k] == false
	msg := sprintf("%s: %s must be true", [r.address, k])
}

deny contains msg if {
	r := resources[_]
	r.type == "aws_iam_policy"
	doc := json.unmarshal(r.change.after.policy)
	stmt := doc.Statement[_]
	stmt.Effect == "Allow"
	stmt.Action == "*"
	msg := sprintf("%s: wildcard Action \"*\" is not allowed", [r.address])
}

deny contains msg if {
	r := resources[_]
	r.type == "aws_db_instance"
	r.change.after.storage_encrypted != true
	msg := sprintf("%s: storage must be encrypted", [r.address])
}

# Taggable resources have tags_all computed at plan time, so it is "unknown".
# Require an owner tag either on the resource or in the provider default_tags.
default_owner_tag := true if {
	input.configuration.provider_config.aws.expressions.default_tags[_].tags.constant_value.owner
} else := false

deny contains msg if {
	r := resources[_]
	r.change.after_unknown.tags_all == true
	not r.change.after.tags.owner
	not default_owner_tag
	msg := sprintf("%s: missing required tag \"owner\" (resource tags or provider default_tags)", [r.address])
}

# Literal secrets in config. The provider marks password as sensitive either
# way, so inspect the configuration: a literal has a constant_value, a variable
# reference does not.
deny contains msg if {
	c := input.configuration.root_module.resources[_]
	c.type == "aws_db_instance"
	is_string(c.expressions.password.constant_value)
	msg := sprintf("%s: password is a literal, use a sensitive variable or a secrets manager", [c.address])
}
# CI gate exercised by a test PR.
