variable "gcp_project_id" {
  description = "Dedicated demo project ID."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID."
  }
}

variable "gcp_region" {
  description = "Region, e.g. us-central1."
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.gcp_region))
    error_message = "gcp_region must look like us-central1."
  }
}

variable "gcp_zone" {
  description = "Zone inside gcp_region, e.g. us-central1-a."
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]-[a-z]$", var.gcp_zone))
    error_message = "gcp_zone must look like us-central1-a."
  }
}

variable "instance_name" {
  description = "Compute Engine instance name and Arc resource name."
  type        = string
  default     = "arc-gcp-demo"
  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.instance_name))
    error_message = "instance_name must satisfy GCE naming (lowercase, digits, hyphens)."
  }
}

variable "machine_type" {
  description = "Low-cost machine type. e2-micro may be free-tier eligible in some US regions; eligibility varies."
  type        = string
  default     = "e2-micro"
  validation {
    condition     = contains(["e2-micro", "e2-small", "e2-medium"], var.machine_type)
    error_message = "Use e2-micro, e2-small or e2-medium."
  }
}

variable "image_family" {
  description = "Public image family for Ubuntu 24.04 LTS (x86-64)."
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

variable "image_project" {
  description = "Project that publishes the image family."
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "subnet_cidr" {
  description = "CIDR for the dedicated demo subnet."
  type        = string
  default     = "10.43.0.0/24"
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR."
  }
}

variable "allow_public_ssh" {
  description = "Lab-only shortcut. Not recommended for production. Opens TCP/22 from ssh_allowed_cidr. Default path is IAP TCP forwarding + OS Login."
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Source CIDR permitted for SSH when allow_public_ssh=true. Use your own /32."
  type        = string
  default     = "203.0.113.10/32"
  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid IPv4 CIDR."
  }
}

variable "owner" {
  description = "owner label value (lowercase)."
  type        = string
  default     = "owner-placeholder"
}

variable "cost_center" {
  description = "costcenter label value (lowercase)."
  type        = string
  default     = "costcenter-placeholder"
}

variable "expiration_date" {
  description = "expirationdate label (YYYY-MM-DD, hyphens allowed)."
  type        = string
  default     = "2026-12-31"
}
