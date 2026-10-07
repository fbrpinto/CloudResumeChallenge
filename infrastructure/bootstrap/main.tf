# ------------------------------------- Bootstrap -------------------------------------- #
# Lets GitHub Actions sign in to AWS with short-lived credentials (OIDC) instead of a
# stored access key. Applied once from a laptop; CI never touches this stack.
terraform {
  backend "s3" {
    bucket       = "crc-fbrpinto-terraform-state"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
  }
}

# ------------------------------------- Providers -------------------------------------- #
provider "aws" {
  region = "eu-west-1"
}


# ----------------------------------- OIDC Provider ------------------------------------ #
# Trust GitHub's token issuer
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}


# ------------------------------------ Deploy Role ------------------------------------- #
# Only workflows running on the main branch of this repo can assume the role
data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

# Create the role used by all workflows
resource "aws_iam_role" "github_actions" {
  name                 = "github-actions-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

# Terraform manages IAM, Lambda, API Gateway, ACM, CloudFront, S3, SNS, CloudWatch and DynamoDB
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


# -------------------------------------- Outputs --------------------------------------- #
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
