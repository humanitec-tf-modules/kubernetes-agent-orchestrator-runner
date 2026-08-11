# Mock all required providers
mock_provider "platform-orchestrator" {}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "local" {}

variables {
  nats_token = "test-token"
}

run "test_basic_aws_irsa" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-123"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    service_account_annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/test-runner-role"
    }
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Default deployment namespace should be 'platform-orchestrator-kubernetes-agent-runner-ns'"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-job-ns"
    error_message = "Default job namespace should be 'platform-orchestrator-kubernetes-agent-runner-job-ns'"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.name == "platform-orchestrator-kubernetes-agent-runner"
    error_message = "Helm release name should be 'platform-orchestrator-kubernetes-agent-runner'"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.chart == "platform-orchestrator-kubernetes-agent-runner"
    error_message = "Helm chart should be 'platform-orchestrator-kubernetes-agent-runner'"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.repository == "oci://ghcr.io/stellwerk-labs/charts"
    error_message = "Helm repository should be 'oci://ghcr.io/stellwerk-labs/charts'"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.namespace == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Helm release should be deployed in the deployment namespace"
  }

  assert {
    condition = !anytrue([
      for s in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      s.name == "image.repository"
    ])
    error_message = "Helm values must not contain \"image.repository\""
  }

  assert {
    condition = !anytrue([
      for s in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      s.name == "image.tag"
    ])
    error_message = "Helm values must not contain \"image.tag\""
  }
}

run "test_basic_gke_workload_identity" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-456"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    service_account_annotations = {
      "iam.gke.io/gcp-service-account" = "test-sa@test-project.iam.gserviceaccount.com"
    }
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Default namespace should be 'platform-orchestrator-kubernetes-agent-runner'"
  }

}

run "test_custom_namespace" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-789"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    k8s_namespace       = "custom-runner-namespace"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "custom-runner-namespace"
    error_message = "Namespace should match the custom value 'custom-runner-namespace'"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.namespace == "custom-runner-namespace"
    error_message = "Helm release namespace should match the custom namespace 'custom-runner-namespace'"
  }
}

run "test_custom_service_account" {
  command = plan

  variables {
    orchestrator_org_id      = "test-org-abc"
    nats_url                 = "nats://nats.example.test:4222"
    public_key_path          = "./tests/fixtures/test_public_key"
    k8s_service_account_name = "custom-service-account"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Should use default namespace when not specified"
  }
}

run "test_minimal_configuration" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-minimal"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Should create namespace with default name"
  }

}

run "test_deprecated_org_id_alias" {
  command = plan

  variables {
    humanitec_org_id = "test-org-legacy"
    nats_url         = "nats://nats.example.test:4222"
    public_key_path  = "./tests/fixtures/test_public_key"
  }

  assert {
    condition     = local.orchestrator_org_id == "test-org-legacy"
    error_message = "The deprecated organization ID alias should remain functional"
  }
}

run "test_runner_id_output" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-output"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
  }

  # Validate that the runner_id output is correctly set from the platform-orchestrator resource
  # Note: In plan mode with mock providers, we cannot validate the exact value
  # but we can ensure the output exists
}

run "test_separate_deployment_job_namespaces" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-separate-ns"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    k8s_namespace       = "runner-deployment"
    k8s_job_namespace   = "runner-jobs"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "runner-deployment"
    error_message = "Deployment namespace should be 'runner-deployment'"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "runner-jobs"
    error_message = "Job namespace should be 'runner-jobs'"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.namespace == "runner-deployment"
    error_message = "Helm release should be in deployment namespace 'runner-deployment'"
  }

  assert {
    condition     = length(kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner) == 1
    error_message = "Should create deployment namespace when different from job namespace"
  }
}

run "test_same_deployment_job_namespace" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-same-ns"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    k8s_namespace       = "unified-namespace"
    k8s_job_namespace   = "unified-namespace"
  }

  assert {
    condition     = length(kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner) == 0
    error_message = "Should not create separate deployment namespace when same as job namespace"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "unified-namespace"
    error_message = "Job namespace should be 'unified-namespace'"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.namespace == "unified-namespace"
    error_message = "Helm release should be in the unified namespace"
  }
}

run "test_custom_service_accounts" {
  command = plan

  variables {
    orchestrator_org_id          = "test-org-sa"
    nats_url                     = "nats://nats.example.test:4222"
    public_key_path              = "./tests/fixtures/test_public_key"
    k8s_service_account_name     = "custom-deployment-sa"
    k8s_job_service_account_name = "custom-job-sa"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Should use default deployment namespace when not specified"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-job-ns"
    error_message = "Should use default job namespace when not specified"
  }
}

run "test_state_storage_configuration" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-state"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    k8s_job_namespace   = "job-namespace-with-state"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "job-namespace-with-state"
    error_message = "Job namespace should be 'job-namespace-with-state'"
  }

  # Note: We can't directly assert on the platform-orchestrator_kubernetes_agent_runner resource
  # configuration in plan mode with mocked providers, but the test ensures the module runs
  # with the correct namespace configuration
}

run "test_default_pod_template" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-pod-default"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
  }

  # Test validates that the module uses the default pod_template
  # The default includes a label "app.kubernetes.io/name" = "platform-orchestrator-runner"
  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-job-ns"
    error_message = "Should use default job namespace"
  }
}

run "test_custom_pod_template_with_labels" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-pod-custom"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    pod_template        = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"platform-orchestrator-runner\",\"app.kubernetes.io/version\" : \"v1.0.0\",\"custom-label\":\"custom-value\"}}}"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-job-ns"
    error_message = "Should create job namespace with custom pod template"
  }

  # Note: We can't assert on the pod_template content directly in plan mode with mocked providers
  # but this test ensures the module accepts custom pod templates without errors
}

run "test_custom_pod_template_with_resources" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-pod-resources"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    pod_template        = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"platform-orchestrator-runner\"},\"annotations\":{\"custom-annotation\":\"value\"}},\"spec\":{\"containers\":[{\"name\":\"runner\",\"resources\":{\"requests\":{\"memory\":\"256Mi\",\"cpu\":\"100m\"},\"limits\":{\"memory\":\"512Mi\",\"cpu\":\"200m\"}}}]}}"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Should create deployment namespace"
  }

  assert {
    condition     = kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job[0].metadata[0].name == "platform-orchestrator-kubernetes-agent-runner-job-ns"
    error_message = "Should create job namespace"
  }
}

run "test_custom_pod_template_with_node_selector" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-pod-selector"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
    pod_template        = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"platform-orchestrator-runner\"}},\"spec\":{\"nodeSelector\":{\"workload-type\":\"platform-orchestrator-runner\",\"node-pool\":\"runner-pool\"},\"tolerations\":[{\"key\":\"dedicated\",\"operator\":\"Equal\",\"value\":\"runner\",\"effect\":\"NoSchedule\"}]}}"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.namespace == "platform-orchestrator-kubernetes-agent-runner-ns"
    error_message = "Helm release should be in deployment namespace"
  }
}

run "test_extra_env_vars_default_empty" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-env-empty"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
  }

  assert {
    condition     = length(local.extra_env_vars_sets) == 0
    error_message = "Should have no extra env vars when not specified"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.name == "platform-orchestrator-kubernetes-agent-runner"
    error_message = "Helm release should be created successfully with empty extra_env_vars"
  }
}

run "test_extra_env_vars_single" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-env-single"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
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
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "platformOrchestrator.extraEnvVars[0].name")
    error_message = "Should contain platformOrchestrator.extraEnvVars[0].name in helm set values"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "platformOrchestrator.extraEnvVars[0].value")
    error_message = "Should contain platformOrchestrator.extraEnvVars[0].value in helm set values"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "platformOrchestrator.extraEnvVars[0].name" && s.value == "MY_CUSTOM_VAR"
    ])
    error_message = "Should have correct name value for platformOrchestrator.extraEnvVars[0].name"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "platformOrchestrator.extraEnvVars[0].value" && s.value == "custom-value"
    ])
    error_message = "Should have correct value for platformOrchestrator.extraEnvVars[0].value"
  }
}

run "test_extra_env_vars_multiple" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-env-multiple"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
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
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "platformOrchestrator.extraEnvVars[0].name")
    error_message = "Should contain platformOrchestrator.extraEnvVars[0].name"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "platformOrchestrator.extraEnvVars[1].name")
    error_message = "Should contain platformOrchestrator.extraEnvVars[1].name"
  }

  assert {
    condition     = contains([for s in local.extra_env_vars_sets : s.name], "platformOrchestrator.extraEnvVars[2].name")
    error_message = "Should contain platformOrchestrator.extraEnvVars[2].name"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "platformOrchestrator.extraEnvVars[0].name" && s.value == "ENV_VAR_ONE"
    ])
    error_message = "First env var name should be ENV_VAR_ONE"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "platformOrchestrator.extraEnvVars[1].value" && s.value == "value-two"
    ])
    error_message = "Second env var value should be value-two"
  }

  assert {
    condition = anytrue([
      for s in local.extra_env_vars_sets : s.name == "platformOrchestrator.extraEnvVars[2].name" && s.value == "ENV_VAR_THREE"
    ])
    error_message = "Third env var name should be ENV_VAR_THREE"
  }
}

run "test_extra_env_vars_helm_integration" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-env-helm"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"
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
    condition     = length(helm_release.platform_orchestrator_kubernetes_agent_runner.set) > 0
    error_message = "Helm release should have set values"
  }

  assert {
    condition     = length(local.extra_env_vars_sets) == 2
    error_message = "Should have 2 helm set entries for the env var"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.name == "platform-orchestrator-kubernetes-agent-runner"
    error_message = "Helm release should be created with both service account annotations and extra env vars"
  }
}

run "test_self_hosted_artefacts" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-123"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"

    kubernetes_agent_runner_chart_repository = "oci://my-registry.io/stellwerk/charts"
    kubernetes_agent_runner_image_repository = "my-registry.io/stellwerk/platform-orchestrator-runner"
    kubernetes_agent_runner_image_tag        = "v1.2.3"
  }

  assert {
    condition     = helm_release.platform_orchestrator_kubernetes_agent_runner.repository == "oci://my-registry.io/stellwerk/charts"
    error_message = "Helm repository should be 'oci://my-registry.io/stellwerk/charts'"
  }
  assert {
    condition = anytrue([
      for s in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      s.name == "image.repository" && s.value == "my-registry.io/stellwerk/platform-orchestrator-runner"
    ])
    error_message = "Helm values must contain image.repository set to 'my-registry.io/stellwerk/platform-orchestrator-runner'"
  }

  assert {
    condition = anytrue([
      for s in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      s.name == "image.tag" && s.value == "v1.2.3"
    ])
    error_message = "Image tag must be \"v1.2.3\""
  }
}

# Cover passing in empty strings to the image variables.
# Doing so must result in the corresponding Helm chart values not being set.
run "test_empty_image_variables" {
  command = plan

  variables {
    orchestrator_org_id = "test-org-123"
    nats_url            = "nats://nats.example.test:4222"
    public_key_path     = "./tests/fixtures/test_public_key"

    kubernetes_agent_runner_image_repository = ""
    kubernetes_agent_runner_image_tag        = ""
  }

  assert {
    condition = !anytrue([
      for s in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      s.name == "image.repository"
    ])
    error_message = "Helm values must not contain \"image.repository\""
  }

  assert {
    condition = !anytrue([
      for s in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      s.name == "image.tag"
    ])
    error_message = "Helm values must not contain \"image.tag\""
  }
}

run "test_airgap_nats_transport" {
  command = plan

  variables {
    orchestrator_org_id                  = "test-org-airgap"
    public_key_path                      = "./tests/fixtures/test_public_key"
    create_namespaces                    = false
    nats_token                           = ""
    nats_mode                            = "airgap"
    nats_url                             = "tls://protected-nats.internal:4222"
    nats_existing_secret                 = "runner-nats-creds"
    nats_job_credentials_existing_secret = "job-nats-creds"
  }

  assert {
    condition = anytrue([
      for setting in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      setting.name == "nats.mode" && setting.value == "airgap"
    ])
    error_message = "The airgap transport mode must be passed to the runner chart."
  }

  assert {
    condition = anytrue([
      for setting in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      setting.name == "nats.url" && setting.value == "tls://protected-nats.internal:4222"
    ])
    error_message = "The protected-side NATS endpoint must be passed to the runner chart."
  }
}

run "test_production_external_nats_secret" {
  command = plan

  variables {
    orchestrator_org_id  = "test-org-production"
    public_key_path      = "./tests/fixtures/test_public_key"
    nats_url             = "tls://nats.example.test:4222"
    nats_token           = ""
    nats_existing_secret = "runner-nats-creds"
    create_namespaces    = false
  }

  assert {
    condition     = length(kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner) == 0 && length(kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job) == 0
    error_message = "Externally managed credential mode must use pre-created namespaces."
  }

  assert {
    condition = anytrue([
      for setting in helm_release.platform_orchestrator_kubernetes_agent_runner.set :
      setting.name == "nats.jobCredentialsExistingSecret" && setting.value == "runner-nats-creds"
    ])
    error_message = "The existing runner Secret must also be used by deployment Jobs by default."
  }
}
