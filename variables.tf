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

variable "private_key_path" {
  description = "The path to the private key file for the kubernetes-agent runner"
  type        = string
}

variable "public_key_path" {
  description = "The path to the public key file for the kubernetes-agent runner"
  type        = string
}

variable "humanitec_org_id" {
  description = "The Humanitec organization ID to be set as a value in the Helm chart"
  type        = string
}

variable "service_account_annotations" {
  description = "Annotations to add to the Kubernetes service account. Use this for cloud provider authentication (e.g., AWS IRSA role ARN or GCP Workload Identity service account)."
  type        = map(string)
  default     = {}
}

variable "k8s_namespace" {
  description = "The Kubernetes namespace where the kubernetes-agent runner should run"
  type        = string
  default     = "humanitec-kubernetes-agent-runner-ns"
}

variable "k8s_job_namespace" {
  description = "The Kubernetes namespace where the deployment jobs run"
  type        = string
  default     = "humanitec-kubernetes-agent-runner-job-ns"
}

variable "k8s_service_account_name" {
  description = "The name of the Kubernetes service account to be assumed by the the kubernetes-agent runner"
  type        = string
  default     = "humanitec-kubernetes-agent-runner"
}

variable "k8s_job_service_account_name" {
  description = "The name of the Kubernetes service account to be assumed by the deployment jobs created by the kubernetes-agent runner"
  type        = string
  default     = "humanitec-kubernetes-agent-runner-job"
}

variable "pod_template" {
  description = "A JSON-encoded pod template to customize the runner pods"
  type        = string
  default     = "{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"humanitec-runner\"}}}"
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
  description = "Version of the Kubernetes Agent Runner Helm chart (optional)"
  type        = string
  default     = null
  nullable    = true
}

variable "kubernetes_agent_runner_chart_repository" {
  description = "Repository of the Kubernetes Agent Runner Helm chart (optional). Defaults to \"oci://ghcr.io/humanitec/charts\""
  type        = string
  default     = "oci://ghcr.io/humanitec/charts"
}

variable "kubernetes_agent_runner_image_repository" {
  description = "Kubernetes Agent Runner image without the tag, e.g. \"my-registry.io/humanitec/humanitec-runner\" (optional). If omitted or set to an empty string (\"\"), defaults to the value defined in the runner chart values.yaml file"
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