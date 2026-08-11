variable "runner_id" {
  description = "The ID of the runner. If not provided, one will be generated using runner_id_prefix"
  type        = string
  default     = null
}

variable "runner_id_prefix" {
  description = "The prefix to use when generating a runner ID. Only used if runner_id is not provided"
  type        = string
  default     = "runner"
}

variable "public_key_path" {
  description = "The path to the public key file for the kubernetes-agent runner"
  type        = string
}

variable "orchestrator_org_id" {
  description = "The Platform Orchestrator organization ID to be set as a value in the Helm chart"
  type        = string
  default     = null
  nullable    = true
}

variable "nats_mode" {
  description = "Runner transport mode: simple, edge, or airgap"
  type        = string
  default     = "simple"
  validation {
    condition     = contains(["simple", "edge", "airgap"], var.nats_mode)
    error_message = "nats_mode must be simple, edge, or airgap."
  }
}

variable "nats_url" {
  description = "NATS endpoint used by the runner. In airgap mode this is the protected-side broker."
  type        = string
}

variable "nats_existing_secret" {
  description = "Secret in the runner namespace containing NATS credentials"
  type        = string
  default     = ""
}

variable "nats_token" {
  description = "NATS token used for local/bootstrap installations. This value is stored in Terraform state; use externally managed Secrets in production."
  type        = string
  default     = ""
  sensitive   = true
}

variable "nats_auth_type" {
  description = "NATS authentication type: token or credentials"
  type        = string
  default     = "token"
  validation {
    condition     = contains(["token", "credentials"], var.nats_auth_type)
    error_message = "nats_auth_type must be token or credentials."
  }
}

variable "nats_credentials_key" {
  description = "Key containing the NATS credentials file in the credential Secrets"
  type        = string
  default     = "creds"
}

variable "nats_ca_enabled" {
  description = "Mount and use a private CA from the NATS credential Secrets"
  type        = bool
  default     = false
}

variable "nats_ca_key" {
  description = "Key containing the NATS CA certificate in the credential Secrets"
  type        = string
  default     = "ca.crt"
}

variable "nats_job_credentials_existing_secret" {
  description = "Secret in the deployment Job namespace containing NATS credentials"
  type        = string
  default     = ""
}

variable "nats_token_key" {
  description = "Key containing the NATS token in the credential Secrets"
  type        = string
  default     = "token"
}

variable "humanitec_org_id" {
  description = "Deprecated alias for orchestrator_org_id"
  type        = string
  default     = null
  nullable    = true
}

variable "create_namespaces" {
  description = "Create runner namespaces. Set false when pre-creating namespaces and externally managed NATS credential Secrets."
  type        = bool
  default     = true
}

variable "service_account_annotations" {
  description = "Annotations to add to the Kubernetes service account. Use this for cloud provider authentication (e.g., AWS IRSA role ARN or GCP Workload Identity service account)."
  type        = map(string)
  default     = {}
}

variable "k8s_namespace" {
  description = "The Kubernetes namespace where the kubernetes-agent runner should run"
  type        = string
  default     = "platform-orchestrator-kubernetes-agent-runner-ns"
}

variable "k8s_job_namespace" {
  description = "The Kubernetes namespace where the deployment jobs run"
  type        = string
  default     = "platform-orchestrator-kubernetes-agent-runner-job-ns"
}

variable "k8s_service_account_name" {
  description = "The name of the Kubernetes service account to be assumed by the the kubernetes-agent runner"
  type        = string
  default     = "platform-orchestrator-kubernetes-agent-runner"
}

variable "k8s_job_service_account_name" {
  description = "The name of the Kubernetes service account to be assumed by the deployment jobs created by the kubernetes-agent runner"
  type        = string
  default     = "platform-orchestrator-kubernetes-agent-runner-job"
}

variable "pod_template" {
  description = "A JSON-encoded pod template to customize the runner pods"
  type        = string
  default     = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"platform-orchestrator-runner\"}}}"
}

variable "extra_env_vars" {
  description = "Additional environment variables to pass to the kubernetes-agent runner pods"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "kubernetes_agent_runner_chart_version" {
  description = "Version of the Kubernetes Agent Runner Helm chart"
  type        = string
  default     = "0.2.0"
}

variable "kubernetes_agent_runner_chart_repository" {
  description = "Repository of the Kubernetes Agent Runner Helm chart (optional). Defaults to \"oci://ghcr.io/stellwerk-labs/charts\""
  type        = string
  default     = "oci://ghcr.io/stellwerk-labs/charts"
}

variable "kubernetes_agent_runner_image_repository" {
  description = "Kubernetes Agent Runner image without the tag, e.g. \"my-registry.io/stellwerk/platform-orchestrator-runner\" (optional). If omitted or set to an empty string (\"\"), defaults to the value defined in the runner chart values.yaml file"
  type        = string
  default     = null
  nullable    = true
}

variable "kubernetes_agent_runner_image_tag" {
  description = "Kubernetes Agent Runner image tag (optional). If omitted or set to an empty string (\"\"), defaults to the value defined in the runner chart values.yaml file"
  type        = string
  default     = null
  nullable    = true
}
