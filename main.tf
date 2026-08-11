resource "random_id" "runner_id" {
  count       = var.runner_id == null ? 1 : 0
  byte_length = 8
  prefix      = "${var.runner_id_prefix}-"
}

# Generate a random suffix to avoid naming conflicts
resource "random_id" "suffix" {
  byte_length = 4
}
locals {
  runner_id                            = var.runner_id != null ? var.runner_id : random_id.runner_id[0].hex
  orchestrator_org_id                  = var.orchestrator_org_id != null ? var.orchestrator_org_id : var.humanitec_org_id
  kubernetes_agent_runner_helm_chart   = "platform-orchestrator-kubernetes-agent-runner"
  kubernetes_agent_runner_helm_release = "platform-orchestrator-kubernetes-agent-runner"
  runner_private_key_secret            = "${local.kubernetes_agent_runner_helm_release}-identity"

  # Build service account annotations for helm set values
  service_account_annotation_sets = [
    for key, value in var.service_account_annotations : {
      name  = "serviceAccount.annotations.${replace(key, ".", "\\.")}"
      value = value
    }
  ]

  # Build extra environment variables for helm set values
  extra_env_vars_sets = flatten([
    for idx, env_var in var.extra_env_vars : [
      {
        name  = "platformOrchestrator.extraEnvVars[${idx}].name"
        value = env_var.name
      },
      {
        name  = "platformOrchestrator.extraEnvVars[${idx}].value"
        value = env_var.value
      }
    ]
  ])

  # Build image repository and image tag sets for helm set values.
  # We must not set a value of "" because that would override the default from the values.yaml
  # and we do not want to duplicate that default value here
  image_repository_sets = (var.kubernetes_agent_runner_image_repository == null) || (var.kubernetes_agent_runner_image_repository == "") ? [] : [
    {
      name : "image.repository"
      value : var.kubernetes_agent_runner_image_repository
    }
  ]
  image_tag_sets = (var.kubernetes_agent_runner_image_tag == null) || (var.kubernetes_agent_runner_image_tag == "") ? [] : [
    {
      name : "image.tag"
      value : var.kubernetes_agent_runner_image_tag
    }
  ]

  deployment_job_different_namespace = var.k8s_namespace != var.k8s_job_namespace
  runner_namespace                   = local.deployment_job_different_namespace ? (var.create_namespaces ? kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name : var.k8s_namespace) : local.job_namespace
  job_namespace                      = var.create_namespaces ? kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name : var.k8s_job_namespace
}

check "orchestrator_org_id" {
  assert {
    condition     = try(trimspace(local.orchestrator_org_id) != "", false)
    error_message = "Set orchestrator_org_id. The deprecated humanitec_org_id alias is accepted during migration."
  }
}

check "edge_outbox" {
  assert {
    condition     = var.outbox_enabled == (var.gateway_mode == "edge")
    error_message = "Edge mode requires outbox_enabled=true; the outbox is not valid in simple or airgap mode."
  }
}

check "airgap_secrets" {
  assert {
    condition     = var.gateway_mode != "airgap" || (var.airgap_gateway_secret != "" && var.airgap_nats_existing_secret != "")
    error_message = "Airgap mode requires airgap_gateway_secret and airgap_nats_existing_secret."
  }
}
