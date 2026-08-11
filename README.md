# Kubernetes Agent Orchestrator Runner

This Terraform module registers a `kubernetes-agent` runner, creates its
namespaces and identity Secret, and installs the runner Helm chart.

The agent initiates outbound HTTPS requests to the runner gateway. It does not
need inbound access from the Orchestrator or broker credentials.

## Create the identity

```bash
openssl genpkey -algorithm ed25519 -out runner_private_key.pem
openssl pkey -in runner_private_key.pem -pubout -out runner_public_key.pem
```

The public key is registered with the Orchestrator. The module stores the
private key in a Kubernetes Secret mounted only by the agent. Like all Secret
resources managed by Terraform, its content is present in Terraform state, so
protect the state backend accordingly. Use the Helm chart directly if Secret
lifecycle must stay outside Terraform.

## Simple mode

```hcl
module "runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=v4.0.0"

  orchestrator_org_id = "my-org"
  public_key_path      = "./runner_public_key.pem"
  private_key_path     = "./runner_private_key.pem"
  gateway_url          = "https://api.orchestrator.example.com/runner-gateway"
}
```

If the endpoint uses a private CA, create a Secret in each applicable namespace
and set `gateway_ca_existing_secret` and `gateway_job_ca_existing_secret`.

## Edge mode

Use the simple-mode configuration plus an RWX-capable outbox:

```hcl
  gateway_mode              = "edge"
  outbox_enabled            = true
  outbox_storage_class_name = "rwx-storage"
```

Commands buffer centrally. The shared outbox buffers results and encrypted
logs until HTTPS connectivity returns. Monitor the resulting PVC capacity and
the outbox flusher logs.

## Air-gapped mode

Set `gateway_mode = "airgap"`, `airgap_gateway_secret`, and
`airgap_nats_existing_secret`. The chart deploys a protected-side gateway and
single-node JetStream. The agent and deployment Jobs still use only local HTTP;
NATS is confined to the protected relay implementation. A separate forward and
reverse file-transfer path is required for commands/bundles and results/logs.

The protected gateway Secret must contain `public-key.pem`,
`runner-token-salt`, and `receipt-key`. The receipt key is the base64 encoding
of exactly 32 random bytes. The token salt must match the central data plane.
The separate NATS Secret must contain a `token` key. Transfer both through the
approved secret-handling process for the protected compartment, then configure:

```hcl
  gateway_mode                    = "airgap"
  gateway_url                     = ""
  airgap_gateway_secret           = "protected-gateway"
  airgap_nats_existing_secret     = "protected-nats-credentials"
```

A physically one-way path cannot return deployment results or logs. Configure
and approve a separate reverse relay when those outputs must reach the central
Orchestrator.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0 |
| <a name="requirement_platform-orchestrator"></a> [platform-orchestrator](#requirement\_platform-orchestrator) | ~> 1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.platform_orchestrator_kubernetes_agent_runner](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret_v1.runner_private_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [platform-orchestrator_kubernetes_agent_runner.my_runner](https://registry.terraform.io/providers/stellwerk-labs/platform-orchestrator/latest/docs/resources/kubernetes_agent_runner) | resource |
| [random_id.runner_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [local_file.agent_runner_public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_sensitive_file.agent_runner_private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/sensitive_file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_airgap_gateway_secret"></a> [airgap\_gateway\_secret](#input\_airgap\_gateway\_secret) | Existing protected-side Secret containing the runner public key, central runner token salt, and a base64-encoded 32-byte receipt key | `string` | `""` | no |
| <a name="input_airgap_nats_existing_secret"></a> [airgap\_nats\_existing\_secret](#input\_airgap\_nats\_existing\_secret) | Existing protected-side Secret containing the local NATS token. Used only inside an air-gapped compartment. | `string` | `""` | no |
| <a name="input_create_namespaces"></a> [create\_namespaces](#input\_create\_namespaces) | Create runner namespaces. Set false when the namespaces and external Secrets are managed separately. | `bool` | `true` | no |
| <a name="input_extra_env_vars"></a> [extra\_env\_vars](#input\_extra\_env\_vars) | Additional environment variables to pass to the kubernetes-agent runner pods | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_gateway_ca_existing_secret"></a> [gateway\_ca\_existing\_secret](#input\_gateway\_ca\_existing\_secret) | Optional Secret containing the private CA used by the gateway | `string` | `""` | no |
| <a name="input_gateway_job_ca_existing_secret"></a> [gateway\_job\_ca\_existing\_secret](#input\_gateway\_job\_ca\_existing\_secret) | Optional copy of the gateway CA Secret in the deployment Job namespace | `string` | `""` | no |
| <a name="input_gateway_mode"></a> [gateway\_mode](#input\_gateway\_mode) | Runner transport mode: simple, edge, or airgap | `string` | `"simple"` | no |
| <a name="input_gateway_url"></a> [gateway\_url](#input\_gateway\_url) | Public HTTPS runner gateway URL. Omit only in airgap mode, where the chart deploys a protected-side gateway. | `string` | `""` | no |
| <a name="input_humanitec_org_id"></a> [humanitec\_org\_id](#input\_humanitec\_org\_id) | Deprecated alias for orchestrator\_org\_id | `string` | `null` | no |
| <a name="input_k8s_job_namespace"></a> [k8s\_job\_namespace](#input\_k8s\_job\_namespace) | The Kubernetes namespace where the deployment jobs run | `string` | `"platform-orchestrator-kubernetes-agent-runner-job-ns"` | no |
| <a name="input_k8s_job_service_account_name"></a> [k8s\_job\_service\_account\_name](#input\_k8s\_job\_service\_account\_name) | The name of the Kubernetes service account to be assumed by the deployment jobs created by the kubernetes-agent runner | `string` | `"platform-orchestrator-kubernetes-agent-runner-job"` | no |
| <a name="input_k8s_namespace"></a> [k8s\_namespace](#input\_k8s\_namespace) | The Kubernetes namespace where the kubernetes-agent runner should run | `string` | `"platform-orchestrator-kubernetes-agent-runner-ns"` | no |
| <a name="input_k8s_service_account_name"></a> [k8s\_service\_account\_name](#input\_k8s\_service\_account\_name) | The name of the Kubernetes service account to be assumed by the the kubernetes-agent runner | `string` | `"platform-orchestrator-kubernetes-agent-runner"` | no |
| <a name="input_kubernetes_agent_runner_chart_repository"></a> [kubernetes\_agent\_runner\_chart\_repository](#input\_kubernetes\_agent\_runner\_chart\_repository) | Repository of the Kubernetes Agent Runner Helm chart (optional). Defaults to "oci://ghcr.io/stellwerk-labs/charts" | `string` | `"oci://ghcr.io/stellwerk-labs/charts"` | no |
| <a name="input_kubernetes_agent_runner_chart_version"></a> [kubernetes\_agent\_runner\_chart\_version](#input\_kubernetes\_agent\_runner\_chart\_version) | Version of the Kubernetes Agent Runner Helm chart | `string` | `"0.3.0"` | no |
| <a name="input_kubernetes_agent_runner_image_repository"></a> [kubernetes\_agent\_runner\_image\_repository](#input\_kubernetes\_agent\_runner\_image\_repository) | Kubernetes Agent Runner image without the tag, e.g. "my-registry.io/stellwerk/platform-orchestrator-runner" (optional). If omitted or set to an empty string (""), defaults to the value defined in the runner chart values.yaml file | `string` | `null` | no |
| <a name="input_kubernetes_agent_runner_image_tag"></a> [kubernetes\_agent\_runner\_image\_tag](#input\_kubernetes\_agent\_runner\_image\_tag) | Kubernetes Agent Runner image tag (optional). If omitted or set to an empty string (""), defaults to the value defined in the runner chart values.yaml file | `string` | `null` | no |
| <a name="input_orchestrator_org_id"></a> [orchestrator\_org\_id](#input\_orchestrator\_org\_id) | The Platform Orchestrator organization ID to be set as a value in the Helm chart | `string` | `null` | no |
| <a name="input_outbox_enabled"></a> [outbox\_enabled](#input\_outbox\_enabled) | Persist deployment results and logs while an edge gateway connection is unavailable | `bool` | `false` | no |
| <a name="input_outbox_storage_class_name"></a> [outbox\_storage\_class\_name](#input\_outbox\_storage\_class\_name) | RWX-capable StorageClass used by the edge outbox | `string` | `""` | no |
| <a name="input_pod_template"></a> [pod\_template](#input\_pod\_template) | A JSON-encoded pod template to customize the runner pods | `string` | `"{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"platform-orchestrator-runner\"}}}"` | no |
| <a name="input_private_key_path"></a> [private\_key\_path](#input\_private\_key\_path) | Path to the Ed25519 private key used by the runner to authenticate to the HTTPS gateway | `string` | n/a | yes |
| <a name="input_public_key_path"></a> [public\_key\_path](#input\_public\_key\_path) | The path to the public key file for the kubernetes-agent runner | `string` | n/a | yes |
| <a name="input_runner_id"></a> [runner\_id](#input\_runner\_id) | The ID of the runner. If not provided, one will be generated using runner\_id\_prefix | `string` | `null` | no |
| <a name="input_runner_id_prefix"></a> [runner\_id\_prefix](#input\_runner\_id\_prefix) | The prefix to use when generating a runner ID. Only used if runner\_id is not provided | `string` | `"runner"` | no |
| <a name="input_service_account_annotations"></a> [service\_account\_annotations](#input\_service\_account\_annotations) | Annotations to add to the Kubernetes service account. Use this for cloud provider authentication (e.g., AWS IRSA role ARN or GCP Workload Identity service account). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_k8s_job_namespace"></a> [k8s\_job\_namespace](#output\_k8s\_job\_namespace) | The Kubernetes namespace where the deployment jobs are executed |
| <a name="output_k8s_job_service_account_name"></a> [k8s\_job\_service\_account\_name](#output\_k8s\_job\_service\_account\_name) | The name of the Kubernetes service account used by the deployment jobs |
| <a name="output_k8s_namespace"></a> [k8s\_namespace](#output\_k8s\_namespace) | The Kubernetes namespace where the runner is deployed |
| <a name="output_k8s_service_account"></a> [k8s\_service\_account](#output\_k8s\_service\_account) | The Kubernetes service account used by the runner |
| <a name="output_runner_helm_chart_version"></a> [runner\_helm\_chart\_version](#output\_runner\_helm\_chart\_version) | Helm chart version of the runner |
| <a name="output_runner_id"></a> [runner\_id](#output\_runner\_id) | The ID of the runner |
<!-- END_TF_DOCS -->
