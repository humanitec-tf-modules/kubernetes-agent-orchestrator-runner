data "local_file" "agent_runner_private_key" {
  filename = var.private_key_path
}

# The namespace for the kubernetes-agent runner deployment. If job and deployment runs in the same namespace, this resource is not created.
resource "kubernetes_namespace" "humanitec_kubernetes_agent_runner" {
  count = local.deployment_job_different_namespace ? 1 : 0
  metadata {
    name = var.k8s_namespace
  }
}

# The namespace for the kubernetes-agent runner deployment job
resource "kubernetes_namespace" "humanitec_kubernetes_agent_runner_job" {
  metadata {
    name = var.k8s_job_namespace
  }
}

# A Secret for the agent runner private key
resource "kubernetes_secret" "agent_runner_key" {
  metadata {
    name      = local.kubernetes_agent_private_key_secret_name
    namespace = local.deployment_job_different_namespace ? kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name : kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
  }

  type = "Opaque"

  data = {
    "private_key" = data.local_file.agent_runner_private_key.content
  }
}

# Install the Kubernetes agent runner Helm chart
resource "helm_release" "humanitec_kubernetes_agent_runner" {
  name             = local.kubernetes_agent_runner_helm_release
  namespace        = local.deployment_job_different_namespace ? kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name : kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
  create_namespace = false
  version          = var.kubernetes_agent_runner_chart_version # Will use latest if null
  repository       = var.kubernetes_agent_runner_chart_repository
  chart            = local.kubernetes_agent_runner_helm_chart

  set = concat(
    [
      {
        name : "humanitec.orgId"
        value : var.humanitec_org_id
      },
      {
        name : "humanitec.runnerId"
        value : platform-orchestrator_kubernetes_agent_runner.my_runner.id
      },
      {
        name : "humanitec.existingSecret"
        value : kubernetes_secret.agent_runner_key.metadata[0].name
      },
      {
        name : "namespaceOverride"
        value : local.deployment_job_different_namespace ? kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name : kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
      },
      {
        name : "serviceAccount.name",
        value : var.k8s_service_account_name
      },
      {
        name : "jobsRbac.namespace"
        value : kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name
      },
      {
        name : "jobsRbac.serviceAccountName"
        value : var.k8s_job_service_account_name
      }
    ],
    local.service_account_annotation_sets,
    local.extra_env_vars_sets,
    local.image_repository_set
  )

  depends_on = [
    kubernetes_namespace.humanitec_kubernetes_agent_runner,
    kubernetes_namespace.humanitec_kubernetes_agent_runner_job
  ]
}
