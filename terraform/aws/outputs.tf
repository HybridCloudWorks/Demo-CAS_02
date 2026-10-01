output "instance_id" {
  description = "EC2 instance ID (target for aws ssm start-session)."
  value       = aws_instance.demo.id
}

output "instance_name" {
  description = "Name tag / intended Arc resource name."
  value       = var.instance_name
}

output "public_ip" {
  description = "Public IPv4 of the instance. Treat as sensitive in screenshots."
  value       = aws_instance.demo.public_ip
  sensitive   = true
}

output "ami_id" {
  description = "Resolved Ubuntu 24.04 AMI."
  value       = data.aws_ssm_parameter.ubuntu.value
}

output "ssm_session_command" {
  description = "Command to open an administrative session without inbound ports."
  value       = "aws ssm start-session --target ${aws_instance.demo.id} --region ${var.aws_region}"
}
