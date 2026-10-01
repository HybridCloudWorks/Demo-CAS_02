locals {
  common_tags = {
    Environment    = "Demo"
    Session        = "AzureArcHybrid"
    Owner          = var.owner
    CloudOrigin    = "AWS"
    ManagedBy      = "Terraform"
    CostCenter     = var.cost_center
    ExpirationDate = var.expiration_date
  }
}

# Current Ubuntu 24.04 LTS AMI published by Canonical through a public SSM parameter.
data "aws_ssm_parameter" "ubuntu" {
  name = var.ubuntu_ssm_parameter
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------- network
resource "aws_vpc" "demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.instance_name}-vpc" }
}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id
  tags   = { Name = "${var.instance_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.demo.id
  cidr_block              = var.vpc_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.instance_name}-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }
  tags = { Name = "${var.instance_name}-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Outbound HTTPS only. No inbound rules unless allow_public_ssh=true (lab-only).
resource "aws_security_group" "demo" {
  name        = "${var.instance_name}-sg"
  description = "Arc demo: outbound 443 for agent, optional restricted SSH"
  vpc_id      = aws_vpc.demo.id
  tags        = { Name = "${var.instance_name}-sg" }
}

resource "aws_vpc_security_group_egress_rule" "https_out" {
  security_group_id = aws_security_group.demo.id
  description       = "Outbound HTTPS for Arc agent, SSM, apt"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "http_out" {
  security_group_id = aws_security_group.demo.id
  description       = "Outbound HTTP for apt mirrors (Ubuntu archive)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dns_out" {
  security_group_id = aws_security_group.demo.id
  description       = "Outbound DNS"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "0.0.0.0/0"
}

# Lab-only shortcut. Not recommended for production. Production path: SSM Session Manager, no inbound port.
resource "aws_vpc_security_group_ingress_rule" "ssh_optional" {
  count             = var.allow_public_ssh ? 1 : 0
  security_group_id = aws_security_group.demo.id
  description       = "LAB ONLY: SSH from instructor CIDR"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_allowed_cidr
}

# ---------------------------------------------------------------- identity (SSM)
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.instance_name}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Managed policy name: verification required against current official documentation.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ssm.name
}

# Optional key pair from an existing PUBLIC key file. No private key is ever generated or stored in state.
resource "aws_key_pair" "optional" {
  count      = var.ssh_public_key_path != "" ? 1 : 0
  key_name   = "${var.instance_name}-key"
  public_key = file(var.ssh_public_key_path)
}

# ---------------------------------------------------------------- compute
resource "aws_instance" "demo" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.demo.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = true
  key_name                    = var.ssh_public_key_path != "" ? aws_key_pair.optional[0].key_name : null
  user_data                   = file("${path.module}/../../scripts/cloud-init.yaml")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 16
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = var.instance_name }

  lifecycle {
    # Canonical publishes new AMIs frequently; do not replace the demo VM on the day of the session.
    ignore_changes = [ami]
  }
}
