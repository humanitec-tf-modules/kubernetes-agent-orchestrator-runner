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

resource "kubernetes_secret_v1" "runner_private_key" {
  metadata {
    name      = local.runner_private_key_secret
    namespace = local.runner_namespace
  }
  data = {
    "private-key.pem" = data.local_sensitive_file.agent_runner_private_key.content
  }
  type = "Opaque"

  depends_on = [
    kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner,
    kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job
  ]
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
        name : "gateway.mode"
        value : var.gateway_mode
      },
      {
        name : "gateway.url"
        value : var.gateway_url
      },
      {
        name : "gateway.privateKeyExistingSecret"
        value : kubernetes_secret_v1.runner_private_key.metadata[0].name
      },
      {
        name : "gateway.caExistingSecret"
        value : var.gateway_ca_existing_secret
      },
      {
        name : "gateway.jobCaExistingSecret"
        value : var.gateway_job_ca_existing_secret
      },
      {
        name : "outbox.enabled"
        value : var.outbox_enabled
      },
      {
        name : "outbox.storageClassName"
        value : var.outbox_storage_class_name
      },
      {
        name : "airgap.gatewaySecret"
        value : var.airgap_gateway_secret
      },
      {
        name : "airgap.nats.existingSecret"
        value : var.airgap_nats_existing_secret
      },
      {
        name : "protected-nats.enabled"
        value : var.gateway_mode == "airgap"
      },
      {
        name : "protected-nats.container.env.NATS_AUTH_TOKEN.valueFrom.secretKeyRef.name"
        value : var.airgap_nats_existing_secret
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

  depends_on = [
    kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner,
    kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job,
    kubernetes_secret_v1.runner_private_key
  ]
}
