output "load_balancer_ip" {
  description = "Địa chỉ IP Public duy nhất của toàn bộ hệ thống (Load Balancer)"
  value       = google_compute_global_forwarding_rule.yas_forwarding_rule.ip_address
}

output "ssh_command" {
  description = "Câu lệnh SSH an toàn qua Google IAP"
  value       = "gcloud compute ssh yas-server --zone=${var.zone} --tunnel-through-iap"
}

output "artifact_registry_url" {
  description = "URL kho chứa Docker Image trên GCP"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.yas_repo.repository_id}"
}

output "frontend_bucket_url" {
  description = "Đường dẫn trực tiếp tới Frontend Tĩnh trên GCS"
  value       = "https://storage.googleapis.com/${google_storage_bucket.frontend_bucket.name}/index.html"
}