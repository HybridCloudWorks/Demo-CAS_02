# Authentication: AWS named profile (SSO or short-lived credentials). No keys in this repo.
#   export AWS_PROFILE=<AWS_PROFILE>
#   aws sso login --profile "$AWS_PROFILE"
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}
