output "load_balancer_ip" {
  description = "IP Public cua Load Balancer"
  value       = google_compute_global_forwarding_rule.yas_forwarding_rule.ip_address
}

output "artifact_registry_url" {
  description = "URL kho chua Docker Image tren GCP"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.yas_repo.repository_id}"
}