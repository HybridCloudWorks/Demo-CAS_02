variable "aws_profile" {
  description = "AWS CLI named profile used for authentication (SSO or short-lived credentials). Never store keys in this repo."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for the demo instance, e.g. us-east-2."
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like us-east-2."
  }
}

variable "instance_name" {
  description = "EC2 Name tag and Arc resource name."
  type        = string
  default     = "arc-aws-demo"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.instance_name))
    error_message = "instance_name must be lowercase letters, digits and hyphens."
  }
}

variable "instance_type" {
  description = "Low-cost x86-64 instance type. t3.micro keeps the agent on x86-64 like the other two VMs."
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3a.micro", "t3a.small"], var.instance_type)
    error_message = "Use a small x86-64 burstable type: t3.micro, t3.small, t3a.micro or t3a.small."
  }
}

variable "ubuntu_ami_owner" {
  description = "AWS account ID that publishes Ubuntu AMIs (Canonical: 099720109477)."
  type        = string
  default     = "099720109477"
}

variable "ubuntu_ami_name_pattern" {
  description = "AMI name pattern for the current Ubuntu 24.04 LTS (Noble) x86-64 gp3 server image."
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "vpc_cidr" {
  description = "CIDR for the dedicated demo VPC."
  type        = string
  default     = "10.42.0.0/24"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "allow_public_ssh" {
  description = "Lab-only shortcut. Not recommended for production. Opens TCP/22 from ssh_allowed_cidr. Default access path is AWS Systems Manager Session Manager (no inbound port)."
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Source CIDR permitted for SSH when allow_public_ssh=true. Use your own /32. 0.0.0.0/0 is accepted only because this lab VM is short-lived, never logged into, and destroyed immediately after the session."
  type        = string
  default     = "203.0.113.10/32"
  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid IPv4 CIDR."
  }
}

variable "ssh_public_key_path" {
  description = "Optional path to an existing SSH public key (never a private key). Empty string disables key-pair creation."
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "<OWNER>"
}

variable "cost_center" {
  description = "CostCenter tag value."
  type        = string
  default     = "<COST_CENTER>"
}

variable "expiration_date" {
  description = "ExpirationDate tag (YYYY-MM-DD). Resources must be destroyed on or before this date."
  type        = string
  default     = "<EXPIRATION_DATE>"
}
