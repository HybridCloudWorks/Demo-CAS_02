output "instance_name" {
  description = "Compute Engine instance name / Arc resource name."
  value       = google_compute_instance.demo.name
}

output "zone" {
  description = "Zone of the instance."
  value       = google_compute_instance.demo.zone
}

output "external_ip" {
  description = "Ephemeral external IP. Treat as sensitive in screenshots."
  value       = google_compute_instance.demo.network_interface[0].access_config[0].nat_ip
  sensitive   = true
}

output "service_account_email" {
  description = "VM service account."
  value       = google_service_account.vm.email
}

output "iap_ssh_command" {
  description = "Administrative access through IAP, no public SSH rule required."
  value       = "gcloud compute ssh ${google_compute_instance.demo.name} --zone ${var.gcp_zone} --project ${var.gcp_project_id} --tunnel-through-iap"
}
