output "runner_id" {
  description = "The ID of the runner"
  value       = platform-orchestrator_kubernetes_agent_runner.my_runner.id
}

output "k8s_job_namespace" {
  description = "The Kubernetes namespace where the deployment jobs are executed"
  value       = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
}

output "k8s_job_service_account_name" {
  description = "The name of the Kubernetes service account used by the deployment jobs"
  value       = var.k8s_job_service_account_name
}

output "k8s_namespace" {
  description = "The Kubernetes namespace where the runner is deployed"
  value       = local.deployment_job_different_namespace ? kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name : kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
}

output "k8s_service_account" {
  description = "The Kubernetes service account used by the runner"
  value       = var.k8s_service_account_name
}
