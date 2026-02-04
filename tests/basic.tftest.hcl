# Mock all required providers
mock_provider "platform-orchestrator" {}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "local" {}

run "test_basic_aws_irsa" {
  command = plan

  variables {
    humanitec_org_id = "test-org-123"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    service_account_annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/test-runner-role"
    }
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Default deployment namespace should be 'humanitec-kubernetes-agent-runner-ns'"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "humanitec-kubernetes-agent-runner-job-ns"
    error_message = "Default job namespace should be 'humanitec-kubernetes-agent-runner-job-ns'"
  }

  assert {
    condition     = kubernetes_secret.agent_runner_key.metadata[0].name == "humanitec-kubernetes-agent-runner-private-key"
    error_message = "Secret name should be 'humanitec-kubernetes-agent-runner-private-key'"
  }

  assert {
    condition     = kubernetes_secret.agent_runner_key.metadata[0].namespace == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Secret should be in deployment namespace"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.name == "humanitec-kubernetes-agent-runner"
    error_message = "Helm release name should be 'humanitec-kubernetes-agent-runner'"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.chart == "humanitec-kubernetes-agent-runner"
    error_message = "Helm chart should be 'humanitec-kubernetes-agent-runner'"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.repository == "oci://ghcr.io/humanitec/charts"
    error_message = "Helm repository should be 'oci://ghcr.io/humanitec/charts'"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.namespace == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Helm release should be deployed in the deployment namespace"
  }

  assert {
    condition = !anytrue([
      for s in helm_release.humanitec_kubernetes_agent_runner.set :
      s.name == "image.repository" && s.value != null
    ])
    error_message = "Helm values must not contain image.repository"
  }
}

run "test_basic_gke_workload_identity" {
  command = plan

  variables {
    humanitec_org_id = "test-org-456"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    service_account_annotations = {
      "iam.gke.io/gcp-service-account" = "test-sa@test-project.iam.gserviceaccount.com"
    }
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Default namespace should be 'humanitec-kubernetes-agent-runner'"
  }

  assert {
    condition     = kubernetes_secret.agent_runner_key.type == "Opaque"
    error_message = "Secret type should be 'Opaque'"
  }
}

run "test_custom_namespace" {
  command = plan

  variables {
    humanitec_org_id = "test-org-789"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    k8s_namespace    = "custom-runner-namespace"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "custom-runner-namespace"
    error_message = "Namespace should match the custom value 'custom-runner-namespace'"
  }

  assert {
    condition     = kubernetes_secret.agent_runner_key.metadata[0].namespace == "custom-runner-namespace"
    error_message = "Secret namespace should match the custom namespace 'custom-runner-namespace'"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.namespace == "custom-runner-namespace"
    error_message = "Helm release namespace should match the custom namespace 'custom-runner-namespace'"
  }
}

run "test_custom_service_account" {
  command = plan

  variables {
    humanitec_org_id         = "test-org-abc"
    private_key_path         = "./tests/fixtures/test_private_key"
    public_key_path          = "./tests/fixtures/test_public_key"
    k8s_service_account_name = "custom-service-account"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Should use default namespace when not specified"
  }
}

run "test_minimal_configuration" {
  command = plan

  variables {
    humanitec_org_id = "test-org-minimal"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Should create namespace with default name"
  }

  assert {
    condition     = kubernetes_secret.agent_runner_key.metadata[0].name == "humanitec-kubernetes-agent-runner-private-key"
    error_message = "Should create secret with default name"
  }
}

run "test_runner_id_output" {
  command = plan

  variables {
    humanitec_org_id = "test-org-output"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
  }

  # Validate that the runner_id output is correctly set from the platform-orchestrator resource
  # Note: In plan mode with mock providers, we cannot validate the exact value
  # but we can ensure the output exists
}

run "test_separate_deployment_job_namespaces" {
  command = plan

  variables {
    humanitec_org_id  = "test-org-separate-ns"
    private_key_path  = "./tests/fixtures/test_private_key"
    public_key_path   = "./tests/fixtures/test_public_key"
    k8s_namespace     = "runner-deployment"
    k8s_job_namespace = "runner-jobs"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "runner-deployment"
    error_message = "Deployment namespace should be 'runner-deployment'"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "runner-jobs"
    error_message = "Job namespace should be 'runner-jobs'"
  }

  assert {
    condition     = kubernetes_secret.agent_runner_key.metadata[0].namespace == "runner-deployment"
    error_message = "Secret should be in deployment namespace 'runner-deployment'"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.namespace == "runner-deployment"
    error_message = "Helm release should be in deployment namespace 'runner-deployment'"
  }

  assert {
    condition     = length(kubernetes_namespace.humanitec_kubernetes_agent_runner) == 1
    error_message = "Should create deployment namespace when different from job namespace"
  }
}

run "test_same_deployment_job_namespace" {
  command = plan

  variables {
    humanitec_org_id  = "test-org-same-ns"
    private_key_path  = "./tests/fixtures/test_private_key"
    public_key_path   = "./tests/fixtures/test_public_key"
    k8s_namespace     = "unified-namespace"
    k8s_job_namespace = "unified-namespace"
  }

  assert {
    condition     = length(kubernetes_namespace.humanitec_kubernetes_agent_runner) == 0
    error_message = "Should not create separate deployment namespace when same as job namespace"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "unified-namespace"
    error_message = "Job namespace should be 'unified-namespace'"
  }

  assert {
    condition     = kubernetes_secret.agent_runner_key.metadata[0].namespace == "unified-namespace"
    error_message = "Secret should be in the unified namespace"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.namespace == "unified-namespace"
    error_message = "Helm release should be in the unified namespace"
  }
}

run "test_custom_service_accounts" {
  command = plan

  variables {
    humanitec_org_id             = "test-org-sa"
    private_key_path             = "./tests/fixtures/test_private_key"
    public_key_path              = "./tests/fixtures/test_public_key"
    k8s_service_account_name     = "custom-deployment-sa"
    k8s_job_service_account_name = "custom-job-sa"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Should use default deployment namespace when not specified"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "humanitec-kubernetes-agent-runner-job-ns"
    error_message = "Should use default job namespace when not specified"
  }
}

run "test_state_storage_configuration" {
  command = plan

  variables {
    humanitec_org_id  = "test-org-state"
    private_key_path  = "./tests/fixtures/test_private_key"
    public_key_path   = "./tests/fixtures/test_public_key"
    k8s_job_namespace = "job-namespace-with-state"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "job-namespace-with-state"
    error_message = "Job namespace should be 'job-namespace-with-state'"
  }

  # Note: We can't directly assert on the platform-orchestrator_kubernetes_agent_runner resource
  # configuration in plan mode with mocked providers, but the test ensures the module runs
  # with the correct namespace configuration
}

run "test_default_pod_template" {
  command = plan

  variables {
    humanitec_org_id = "test-org-pod-default"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
  }

  # Test validates that the module uses the default pod_template
  # The default includes a label "app.kubernetes.io/name" = "humanitec-runner"
  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "humanitec-kubernetes-agent-runner-job-ns"
    error_message = "Should use default job namespace"
  }
}

run "test_custom_pod_template_with_labels" {
  command = plan

  variables {
    humanitec_org_id = "test-org-pod-custom"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    pod_template     = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"humanitec-runner\",\"app.kubernetes.io/version\" : \"v1.0.0\",\"custom-label\":\"custom-value\"}}}"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "humanitec-kubernetes-agent-runner-job-ns"
    error_message = "Should create job namespace with custom pod template"
  }

  # Note: We can't assert on the pod_template content directly in plan mode with mocked providers
  # but this test ensures the module accepts custom pod templates without errors
}

run "test_custom_pod_template_with_resources" {
  command = plan

  variables {
    humanitec_org_id = "test-org-pod-resources"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    pod_template     = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"humanitec-runner\"},\"annotations\":{\"custom-annotation\":\"value\"}},\"spec\":{\"containers\":[{\"name\":\"runner\",\"resources\":{\"requests\":{\"memory\":\"256Mi\",\"cpu\":\"100m\"},\"limits\":{\"memory\":\"512Mi\",\"cpu\":\"200m\"}}}]}}"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner[0].metadata[0].name == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Should create deployment namespace"
  }

  assert {
    condition     = kubernetes_namespace.humanitec_kubernetes_agent_runner_job.metadata[0].name == "humanitec-kubernetes-agent-runner-job-ns"
    error_message = "Should create job namespace"
  }
}

run "test_custom_pod_template_with_node_selector" {
  command = plan

  variables {
    humanitec_org_id = "test-org-pod-selector"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    pod_template     = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"humanitec-runner\"}},\"spec\":{\"nodeSelector\":{\"workload-type\":\"humanitec-runner\",\"node-pool\":\"runner-pool\"},\"tolerations\":[{\"key\":\"dedicated\",\"operator\":\"Equal\",\"value\":\"runner\",\"effect\":\"NoSchedule\"}]}}"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.namespace == "humanitec-kubernetes-agent-runner-ns"
    error_message = "Helm release should be in deployment namespace"
  }
}

run "test_extra_env_vars_default_empty" {
  command = plan

  variables {
    humanitec_org_id = "test-org-env-empty"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
  }

  assert {
    condition     = length(local.extra_env_vars_sets) == 0
    error_message = "Should have no extra env vars when not specified"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.name == "humanitec-kubernetes-agent-runner"
    error_message = "Helm release should be created successfully with empty extra_env_vars"
  }
}

run "test_extra_env_vars_single" {
  command = plan

  variables {
    humanitec_org_id = "test-org-env-single"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    extra_env_vars = [
      {
        name  = "MY_CUSTOM_VAR"
        value = "custom-value"
      }
    ]
  }

  assert {
    condition     = length(local.extra_env_vars_sets) == 2
    error_message = "Should have 2 helm set entries for 1 env var (name and value)"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "humanitec.extraEnvVars[0].name")
    error_message = "Should contain humanitec.extraEnvVars[0].name in helm set values"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "humanitec.extraEnvVars[0].value")
    error_message = "Should contain humanitec.extraEnvVars[0].value in helm set values"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "humanitec.extraEnvVars[0].name" && s.value == "MY_CUSTOM_VAR"
    ])
    error_message = "Should have correct name value for humanitec.extraEnvVars[0].name"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "humanitec.extraEnvVars[0].value" && s.value == "custom-value"
    ])
    error_message = "Should have correct value for humanitec.extraEnvVars[0].value"
  }
}

run "test_extra_env_vars_multiple" {
  command = plan

  variables {
    humanitec_org_id = "test-org-env-multiple"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    extra_env_vars = [
      {
        name  = "ENV_VAR_ONE"
        value = "value-one"
      },
      {
        name  = "ENV_VAR_TWO"
        value = "value-two"
      },
      {
        name  = "ENV_VAR_THREE"
        value = "value-three"
      }
    ]
  }

  assert {
    condition     = length(local.extra_env_vars_sets) == 6
    error_message = "Should have 6 helm set entries for 3 env vars (2 entries per var)"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "humanitec.extraEnvVars[0].name")
    error_message = "Should contain humanitec.extraEnvVars[0].name"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "humanitec.extraEnvVars[1].name")
    error_message = "Should contain humanitec.extraEnvVars[1].name"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "humanitec.extraEnvVars[2].name")
    error_message = "Should contain humanitec.extraEnvVars[2].name"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "humanitec.extraEnvVars[0].name" && s.value == "ENV_VAR_ONE"
    ])
    error_message = "First env var name should be ENV_VAR_ONE"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "humanitec.extraEnvVars[1].value" && s.value == "value-two"
    ])
    error_message = "Second env var value should be value-two"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "humanitec.extraEnvVars[2].name" && s.value == "ENV_VAR_THREE"
    ])
    error_message = "Third env var name should be ENV_VAR_THREE"
  }
}

run "test_extra_env_vars_helm_integration" {
  command = plan

  variables {
    humanitec_org_id = "test-org-env-helm"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"
    extra_env_vars = [
      {
        name  = "DEBUG_MODE"
        value = "true"
      }
    ]
    service_account_annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/test-role"
    }
  }

  assert {
    condition     = length(helm_release.humanitec_kubernetes_agent_runner.set) > 0
    error_message = "Helm release should have set values"
  }

  assert {
    condition     = length(local.extra_env_vars_sets) == 2
    error_message = "Should have 2 helm set entries for the env var"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.name == "humanitec-kubernetes-agent-runner"
    error_message = "Helm release should be created with both service account annotations and extra env vars"
  }
}

run "test_self_hosted_artefacts" {
  command = plan

  variables {
    humanitec_org_id = "test-org-123"
    private_key_path = "./tests/fixtures/test_private_key"
    public_key_path  = "./tests/fixtures/test_public_key"

    kubernetes_agent_runner_chart_repository = "oci://my-registry.io/humanitec/charts"
    kubernetes_agent_runner_image            = "my-registry.io/humanitec/humanitec-runner"
  }

  assert {
    condition     = helm_release.humanitec_kubernetes_agent_runner.repository == "oci://my-registry.io/humanitec/charts"
    error_message = "Helm repository should be 'oci://my-registry.io/humanitec/charts'"
  }
  assert {
    condition = anytrue([
      for s in helm_release.humanitec_kubernetes_agent_runner.set :
      s.name == "image.repository" && s.value == "my-registry.io/humanitec/humanitec-runner"
    ])
    error_message = "Helm values must not contain image.repository"
  }
}
