# The namespace for the kubernetes-agent runner deployment. If job and deployment runs in the same namespace, this resource is not created.
resource "kubernetes_namespace" "platform_orchestrator_kubernetes_agent_runner" {
  count = var.create_namespaces && local.deployment_job_different_namespace ? 1 : 0
  metadata {
    name = var.k8s_namespace
  }
}

# The namespace for the kubernetes-agent runner deployment job
resource "kubernetes_namespace" "platform_orchestrator_kubernetes_agent_runner_job" {
  count = var.create_namespaces ? 1 : 0
  metadata {
    name = var.k8s_job_namespace
  }
}

# Install the Kubernetes agent runner Helm chart
resource "helm_release" "platform_orchestrator_kubernetes_agent_runner" {
  name             = local.kubernetes_agent_runner_helm_release
  namespace        = local.runner_namespace
  create_namespace = false
  version          = var.kubernetes_agent_runner_chart_version # Will use latest if null
  repository       = var.kubernetes_agent_runner_chart_repository
  chart            = local.kubernetes_agent_runner_helm_chart

  set = concat(
    [
      {
        name : "platformOrchestrator.orgId"
        value : local.orchestrator_org_id
      },
      {
        name : "platformOrchestrator.runnerId"
        value : platform-orchestrator_kubernetes_agent_runner.my_runner.id
      },
      {
        name : "nats.mode"
        value : var.nats_mode
      },
      {
        name : "nats.url"
        value : var.nats_url
      },
      {
        name : "nats.existingSecret"
        value : var.nats_existing_secret
      },
      {
        name : "nats.authType"
        value : var.nats_auth_type
      },
      {
        name : "nats.credentialsKey"
        value : var.nats_credentials_key
      },
      {
        name : "nats.caEnabled"
        value : var.nats_ca_enabled
      },
      {
        name : "nats.caKey"
        value : var.nats_ca_key
      },
      {
        name : "nats.jobCredentialsExistingSecret"
        value : local.nats_job_credentials_secret
      },
      {
        name : "nats.tokenKey"
        value : var.nats_token_key
      },
      {
        name : "namespaceOverride"
        value : local.runner_namespace
      },
      {
        name : "serviceAccount.name",
        value : var.k8s_service_account_name
      },
      {
        name : "jobsRbac.namespace"
        value : local.job_namespace
      },
      {
        name : "jobsRbac.serviceAccountName"
        value : var.k8s_job_service_account_name
      }
    ],
    local.image_repository_sets,
    local.image_tag_sets,
    local.service_account_annotation_sets,
    local.extra_env_vars_sets
  )

  set_sensitive = var.nats_token == "" ? [] : [
    {
      name  = "nats.token"
      value = var.nats_token
    }
  ]

  depends_on = [
    kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner,
    kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job
  ]
}
