# Reusable Platform Orchestrator Kubernetes Agent Runner

A reusable Terraform module for setting up a Kubernetes Agent Runner for the Humanitec Platform Orchestrator.

## Overview

This module provides a reusable configuration for deploying a Kubernetes-based agent runner that integrates with the Humanitec Platform Orchestrator. The module handles:

- Creating dedicated Kubernetes namespaces for the runner deployment and jobs (can be the same or separate)
- Deploying the Humanitec Kubernetes agent runner via Helm
- Managing runner authentication keys via Kubernetes secrets
- Configuring service account annotations for cloud provider authentication (AWS IRSA, GKE Workload Identity, etc.)
- Configuring state storage in the job namespace

### Namespace Separation

The module supports two deployment patterns:

1. **Separate Namespaces** (default): The runner deployment and jobs run in different namespaces
   - `k8s_namespace`: Where the runner pod runs (default: `humanitec-kubernetes-agent-runner-ns`)
   - `k8s_job_namespace`: Where deployment jobs execute (default: `humanitec-kubernetes-agent-runner-job-ns`)

2. **Unified Namespace**: Both runner and jobs run in the same namespace
   - Set both `k8s_namespace` and `k8s_job_namespace` to the same value
   - Only one namespace will be created

## Prerequisites

Before using this module, ensure you have:

1. **A Kubernetes cluster** deployed and accessible:
   - **AWS EKS**: Use the [AWS EKS Terraform module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) or your own EKS setup
   - **GCP GKE**: Use the [GCP GKE Terraform module](https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest) or your own GKE setup
   - **Azure AKS**: Use the [Azure AKS Terraform module](https://registry.terraform.io/modules/Azure/aks/azurerm/latest) or your own AKS setup
   - Or any other Kubernetes cluster (on-premises, managed, etc.)

2. **Cloud provider authentication configured** (if deploying to cloud-managed Kubernetes):
   - **AWS EKS with IRSA**:
     - OIDC provider enabled on your EKS cluster
     - IAM role created with trust policy for the service account
     - IAM role should have permissions to access resources the runner needs
   - **GCP GKE with Workload Identity**:
     - Workload Identity enabled on your GKE cluster
     - GCP service account created and granted necessary permissions
     - IAM binding between Kubernetes service account and GCP service account

3. **Generated SSH key pair** for the runner authentication:

   ```bash
   openssl genpkey -algorithm ed25519 -out runner_private_key.pem
   openssl pkey -in runner_private_key.pem -pubout -out runner_public_key.pem
   # This creates runner_private_key.pem (private) and runner_public_key.pem (public)
   ```

4. **Kubernetes and Helm providers configured** in your Terraform configuration (see Usage examples below)

## Usage

### AWS EKS with IRSA Example

This example shows a complete setup including EKS cluster creation and runner deployment.

```hcl
# Create VPC for EKS
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "humanitec-runner-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Create EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "humanitec-runner-cluster"
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
    }
  }
}

# Create IAM role for the runner with IRSA
module "runner_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "humanitec-runner-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["humanitec-kubernetes-agent-runner-job-ns:humanitec-kubernetes-agent-runner-job"]
    }
  }

  # Add policies needed by the runner (example: access to AWS resources)
  role_policy_arns = {
    # Add any additional policies your runner needs
    # For example:
    # ecr_read = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-east-1"]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-east-1"]
    }
  }
}

# Deploy the Humanitec runner
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = var.orchestrator_org_id
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  # AWS IRSA configuration - link to the IAM role created above
  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = module.runner_irsa_role.iam_role_arn
  }

  depends_on = [module.eks]
}
```

### GKE with Workload Identity Example

This example shows a complete setup including GKE cluster creation and runner deployment.

```hcl
# Create VPC for GKE
module "gcp_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 12.0"

  project_id   = var.project_id
  network_name = "humanitec-runner-network"

  subnets = [
    {
      subnet_name   = "humanitec-runner-subnet"
      subnet_ip     = "10.0.0.0/24"
      subnet_region = var.gcp_region
    }
  ]

  secondary_ranges = {
    humanitec-runner-subnet = [
      {
        range_name    = "gke-pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "gke-services"
        ip_cidr_range = "10.2.0.0/16"
      },
    ]
  }
}

# Create GKE cluster with Workload Identity enabled
module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 41.0"

  project_id = var.project_id
  name       = "humanitec-runner-cluster"
  region     = var.gcp_region

  network           = module.gcp_network.network_name
  subnetwork        = module.gcp_network.subnets_names[0]
  ip_range_pods     = "gke-pods"
  ip_range_services = "gke-services"

  # Enable Workload Identity
  identity_namespace = "${var.project_id}.svc.id.goog"

  node_pools = [
    {
      name         = "humanitec-runner-pool"
      machine_type = "e2-medium"
      min_count    = 1
      max_count    = 3
      disk_size_gb = 100
      auto_upgrade = true
    }
  ]
}

# Create GCP Service Account for the runner
resource "google_service_account" "runner_sa" {
  account_id   = "humanitec-runner"
  display_name = "Humanitec Kubernetes Agent Runner"
  project      = var.project_id
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "runner_permissions" {
  for_each = toset([
    # Add the roles your runner needs, for example:
    # "roles/storage.objectViewer",
    # "roles/container.developer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runner_sa.email}"
}

# Bind Kubernetes service account to GCP service account
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.runner_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.project_id}.svc.id.goog[${module.kubernetes_agent_runner.k8s_job_namespace}/${module.kubernetes_agent_runner.k8s_job_service_account_name}]"
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes = {
    host                   = "https://${module.gke.endpoint}"
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
   }
  }
}

# Get current GCP client config
data "google_client_config" "default" {}

# Deploy the Humanitec runner
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  # GKE Workload Identity configuration - link to the GCP service account created above
  service_account_annotations = {
    "iam.gke.io/gcp-service-account" = google_service_account.runner_sa.email
  }

  depends_on = [
    module.gke,
  ]
}
```

### With Separate Deployment and Job Namespaces

This example shows how to run the runner pod and deployment jobs in different namespaces.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  # Runner pod runs here
  k8s_namespace     = "humanitec-runner-system"
  # Deployment jobs run here
  k8s_job_namespace = "humanitec-deployments"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/humanitec-runner-role"
  }
}
```

### With Unified Namespace

This example shows how to run both the runner pod and deployment jobs in the same namespace.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  # Both runner and jobs use the same namespace
  k8s_namespace     = "humanitec-unified"
  k8s_job_namespace = "humanitec-unified"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/humanitec-runner-role"
  }
}
```

### With Custom Service Account Names

This example shows how to customize the service account names for both the runner and jobs.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  # Service account for the runner pod
  k8s_service_account_name = "humanitec-runner-sa"
  # Service account for deployment jobs
  k8s_job_service_account_name = "humanitec-job-sa"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/humanitec-runner-role"
  }
}
```

### With Custom Runner ID

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"
  runner_id        = "production-runner"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/humanitec-runner-role"
  }
}
```

### With Extra Environment Variables

This example shows how to pass additional environment variables to the kubernetes-agent runner pods.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  # Additional environment variables for the runner
  extra_env_vars = [
    {
      name  = "HTTP_PROXY"
      value = "http://proxy.example.com:8080"
    },
    {
      name  = "HTTPS_PROXY"
      value = "http://proxy.example.com:8080"
    },
    {
      name  = "NO_PROXY"
      value = "localhost,127.0.0.1,.svc,.cluster.local"
    }
  ]

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/humanitec-runner-role"
  }
}
```

### With Custom Pod Template (Resource Limits)

This example shows how to customize the pod template for deployment jobs with resource limits and requests.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  pod_template = jsonencode({
    metadata = {
      labels = {
        "app.kubernetes.io/name"    = "humanitec-runner"
        "app.kubernetes.io/version" = "v1.0.0"
      }
    }
    spec = {
      containers = [{
        name = "runner"
        resources = {
          requests = {
            memory = "512Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "1Gi"
            cpu    = "500m"
          }
        }
      }]
    }
  })

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/humanitec-runner-role"
  }
}
```

### With Custom Pod Template (Node Selector and Tolerations)

This example shows how to use node selectors and tolerations to control pod placement.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"

  pod_template = jsonencode({
    metadata = {
      labels = {
        "app.kubernetes.io/name" = "humanitec-runner"
      }
    }
    spec = {
      nodeSelector = {
        "workload-type" = "humanitec-deployments"
        "node-pool"     = "runner-pool"
      }
      tolerations = [{
        key      = "dedicated"
        operator = "Equal"
        value    = "runner"
        effect   = "NoSchedule"
      }]
    }
  })

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/humanitec-runner-role"
  }
}
```

### Minimal Configuration (No Cloud Provider Auth)

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/humanitec-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  humanitec_org_id = "my-org-id"
  private_key_path = "./runner_private_key.pem"
  public_key_path  = "./runner_public_key.pem"
}
```

### Default `pod_template`:

```json
{
  "metadata": {
    "labels": {
      "app.kubernetes.io/name": "humanitec-runner"
    }
  }
}
```

## Architecture

This module creates the following resources:

1. **Kubernetes Namespaces**:
   - Deployment namespace (optional - only created if different from job namespace): Where the runner pod is deployed
   - Job namespace (always created): Where deployment jobs execute and state is stored
2. **Kubernetes Secret**: Stores the private key used for runner authentication (created in the deployment namespace)
3. **Helm Release**: Deploys the Humanitec Kubernetes agent runner chart from `oci://ghcr.io/humanitec/charts/humanitec-kubernetes-agent-runner`
4. **Platform Orchestrator Runner**: Registers the runner with Humanitec Platform Orchestrator, configured to:
   - Use the job namespace for deployment execution
   - Store state in the job namespace using Kubernetes backend

## Authentication Methods

The module supports various Kubernetes authentication methods through the `service_account_annotations` variable:

### AWS EKS with IRSA

```hcl
service_account_annotations = {
  "eks.amazonaws.com/role-arn" = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
}
```

### GKE with Workload Identity

```hcl
service_account_annotations = {
  "iam.gke.io/gcp-service-account" = "SERVICE_ACCOUNT@PROJECT_ID.iam.gserviceaccount.com"
}
```

### Custom Annotations

You can add any custom annotations required by your authentication method:

```hcl
service_account_annotations = {
  "custom.annotation/key1" = "value1"
  "custom.annotation/key2" = "value2"
}
```

## Testing

This module includes comprehensive tests that can be run with:

```bash
cd orchestrator-configuration/runner/kubernetes-agent
terraform init
terraform test
```

The test suite validates:

- Basic AWS IRSA authentication setup
- GKE Workload Identity authentication setup
- Custom namespace configuration
- Custom service account configuration
- Minimal configuration
- Output validation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0 |
| <a name="requirement_platform-orchestrator"></a> [platform-orchestrator](#requirement\_platform-orchestrator) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_platform-orchestrator"></a> [platform-orchestrator](#provider\_platform-orchestrator) | 2.10.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.humanitec_kubernetes_agent_runner](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.humanitec_kubernetes_agent_runner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.humanitec_kubernetes_agent_runner_job](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.agent_runner_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [platform-orchestrator_kubernetes_agent_runner.my_runner](https://registry.terraform.io/providers/humanitec/platform-orchestrator/latest/docs/resources/kubernetes_agent_runner) | resource |
| [random_id.runner_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [local_file.agent_runner_private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.agent_runner_public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_extra_env_vars"></a> [extra\_env\_vars](#input\_extra\_env\_vars) | Additional environment variables to pass to the kubernetes-agent runner pods | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_humanitec_org_id"></a> [humanitec\_org\_id](#input\_humanitec\_org\_id) | The Humanitec organization ID to be set as a value in the Helm chart | `string` | n/a | yes |
| <a name="input_k8s_job_namespace"></a> [k8s\_job\_namespace](#input\_k8s\_job\_namespace) | The Kubernetes namespace where the deployment jobs run | `string` | `"humanitec-kubernetes-agent-runner-job-ns"` | no |
| <a name="input_k8s_job_service_account_name"></a> [k8s\_job\_service\_account\_name](#input\_k8s\_job\_service\_account\_name) | The name of the Kubernetes service account to be assumed by the deployment jobs created by the kubernetes-agent runner | `string` | `"humanitec-kubernetes-agent-runner-job"` | no |
| <a name="input_k8s_namespace"></a> [k8s\_namespace](#input\_k8s\_namespace) | The Kubernetes namespace where the kubernetes-agent runner should run | `string` | `"humanitec-kubernetes-agent-runner-ns"` | no |
| <a name="input_k8s_service_account_name"></a> [k8s\_service\_account\_name](#input\_k8s\_service\_account\_name) | The name of the Kubernetes service account to be assumed by the the kubernetes-agent runner | `string` | `"humanitec-kubernetes-agent-runner"` | no |
| <a name="input_pod_template"></a> [pod\_template](#input\_pod\_template) | A JSON-encoded pod template to customize the runner pods | `string` | `"{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"humanitec-runner\"}}}"` | no |
| <a name="input_private_key_path"></a> [private\_key\_path](#input\_private\_key\_path) | The path to the private key file for the kubernetes-agent runner | `string` | n/a | yes |
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
| <a name="output_runner_id"></a> [runner\_id](#output\_runner\_id) | The ID of the runner |
<!-- END_TF_DOCS -->