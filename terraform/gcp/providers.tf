# Authentication: Google Application Default Credentials. No key files in this repo.
#   gcloud auth login
#   gcloud auth application-default login
#   gcloud config set project <GCP_PROJECT_ID>
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}
