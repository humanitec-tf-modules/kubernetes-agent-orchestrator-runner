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

variable "private_key_path" {
  description = "Path to the Ed25519 private key used by the runner to authenticate to the HTTPS gateway"
  type        = string
}

variable "orchestrator_org_id" {
  description = "The Platform Orchestrator organization ID to be set as a value in the Helm chart"
  type        = string
  default     = null
  nullable    = true
}

variable "gateway_mode" {
  description = "Runner transport mode: simple, edge, or airgap"
  type        = string
  default     = "simple"
  validation {
    condition     = contains(["simple", "edge", "airgap"], var.gateway_mode)
    error_message = "gateway_mode must be simple, edge, or airgap."
  }
}

variable "gateway_url" {
  description = "Public HTTPS runner gateway URL. Omit only in airgap mode, where the chart deploys a protected-side gateway."
  type        = string
  default     = ""
  validation {
    condition     = var.gateway_mode == "airgap" || can(regex("^https://", var.gateway_url))
    error_message = "gateway_url must use HTTPS outside airgap mode."
  }
}

variable "gateway_ca_existing_secret" {
  description = "Optional Secret containing the private CA used by the gateway"
  type        = string
  default     = ""
}

variable "gateway_job_ca_existing_secret" {
  description = "Optional copy of the gateway CA Secret in the deployment Job namespace"
  type        = string
  default     = ""
}

variable "outbox_enabled" {
  description = "Persist deployment results and logs while an edge gateway connection is unavailable"
  type        = bool
  default     = false
}

variable "outbox_storage_class_name" {
  description = "RWX-capable StorageClass used by the edge outbox"
  type        = string
  default     = ""
}

variable "airgap_gateway_secret" {
  description = "Existing protected-side Secret containing the runner public key, central runner token salt, and a base64-encoded 32-byte receipt key"
  type        = string
  default     = ""
}

variable "airgap_nats_existing_secret" {
  description = "Existing protected-side Secret containing the local NATS token. Used only inside an air-gapped compartment."
  type        = string
  default     = ""
}

variable "humanitec_org_id" {
  description = "Deprecated alias for orchestrator_org_id"
  type        = string
  default     = null
  nullable    = true
}

variable "create_namespaces" {
  description = "Create runner namespaces. Set false when the namespaces and external Secrets are managed separately."
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
  default     = "0.3.0"
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
