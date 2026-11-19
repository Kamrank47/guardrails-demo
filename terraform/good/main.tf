# The reviewed version: same intent, passes every policy.
provider "aws" {
  region = "eu-west-2"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  default_tags { tags = { owner = "platform", managed_by = "terraform" } }
}

resource "aws_security_group" "app" { name = "app" }

resource "aws_security_group_rule" "https_in" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}

resource "aws_iam_policy" "app" {
  name = "app"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::app-assets/*" }]
  })
}

variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "db" {
  identifier          = "app"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "app"
  password            = var.db_password
  storage_encrypted   = true
  skip_final_snapshot = false
}
