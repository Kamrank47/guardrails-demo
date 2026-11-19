# Typical "first draft" an AI assistant produces for "give me a quick app stack".
# It works, and it is wrong in four ways. The pipeline must block it.
provider "aws" {
  region = "eu-west-2"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

resource "aws_security_group" "app" {
  name = "app"
}

resource "aws_security_group_rule" "ssh_from_anywhere" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # blocked: world-open SSH
  security_group_id = aws_security_group.app.id
}

resource "aws_iam_policy" "app" {
  name = "app"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "*", Resource = "*" }] # blocked: wildcard
  })
}

resource "aws_db_instance" "db" {
  identifier          = "app"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "app"
  password            = "changeme123" # also caught by secret scanning
  storage_encrypted   = false         # blocked
  skip_final_snapshot = true
}
