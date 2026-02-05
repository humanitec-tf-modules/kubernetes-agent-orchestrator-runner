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
  runner_id                                = var.runner_id != null ? var.runner_id : random_id.runner_id[0].hex
  kubernetes_agent_private_key_secret_name = "humanitec-kubernetes-agent-runner-private-key"
  kubernetes_agent_runner_helm_chart       = "humanitec-kubernetes-agent-runner"
  kubernetes_agent_runner_helm_release     = "humanitec-kubernetes-agent-runner"

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
        name  = "humanitec.extraEnvVars[${idx}].name"
        value = env_var.name
      },
      {
        name  = "humanitec.extraEnvVars[${idx}].value"
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
}
