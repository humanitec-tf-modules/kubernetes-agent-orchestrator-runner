data "local_file" "agent_runner_public_key" {
  filename = var.public_key_path
}

resource "platform-orchestrator_kubernetes_agent_runner" "my_runner" {
  id          = local.runner_id
  description = "runner for all the envs"
  runner_configuration = {
    key = data.local_file.agent_runner_public_key.content
    job = {
      namespace       = resource.kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
      service_account = var.k8s_job_service_account_name
      pod_template    = var.pod_template
    }
  }
  state_storage_configuration = {
    type = "kubernetes"
    kubernetes_configuration = {
      namespace = resource.kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
    }
  }
}
