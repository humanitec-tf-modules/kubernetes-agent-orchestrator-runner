# Reusable Platform Orchestrator Kubernetes Agent Runner

A reusable Terraform module for setting up a Kubernetes Agent Runner for the Platform Orchestrator.

## Overview

This module provides a reusable configuration for deploying a Kubernetes-based agent runner that integrates with the Platform Orchestrator. The module handles:

- Creating dedicated Kubernetes namespaces for the runner deployment and jobs (can be the same or separate)
- Deploying the Platform Orchestrator Kubernetes agent runner via Helm
- Connecting the runner and deployment Jobs to NATS with existing Kubernetes
  Secrets
- Configuring service account annotations for cloud provider authentication (AWS IRSA, GKE Workload Identity, etc.)
- Configuring state storage in the job namespace

### Namespace Separation

The module supports two deployment patterns:

1. **Separate Namespaces** (default): The runner deployment and jobs run in different namespaces
   - `k8s_namespace`: Where the runner pod runs (default: `platform-orchestrator-kubernetes-agent-runner-ns`)
   - `k8s_job_namespace`: Where deployment jobs execute (default: `platform-orchestrator-kubernetes-agent-runner-job-ns`)

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

3. **Runner registration key pair**. The public key is registered with the
   Platform Orchestrator; the private key remains local and is not mounted into
   the NATS runner:

   ```bash
   openssl genpkey -algorithm ed25519 -out runner_private_key.pem
   openssl pkey -in runner_private_key.pem -pubout -out runner_public_key.pem
   # This creates runner_private_key.pem (private) and runner_public_key.pem (public)
   ```

4. **NATS credentials** in both runner namespaces when they differ. The broker
   endpoint must be reachable from the runner cluster. For token authentication:

   ```shell
   kubectl create namespace platform-orchestrator-kubernetes-agent-runner-ns
   kubectl create namespace platform-orchestrator-kubernetes-agent-runner-job-ns
   kubectl create secret generic runner-nats-creds \
     --namespace platform-orchestrator-kubernetes-agent-runner-ns \
     --from-literal=token='<runner-token>'
   kubectl create secret generic runner-nats-creds \
     --namespace platform-orchestrator-kubernetes-agent-runner-job-ns \
     --from-literal=token='<runner-token>'
   ```

   Set `create_namespaces = false` when using these externally managed Secrets.
   This lets the credentials exist before Helm waits for the runner. For local
   bootstrap only, the module also accepts sensitive `nats_token`; that value is
   stored in Terraform state and should not be used for production credentials.

5. **Kubernetes and Helm providers configured** in your Terraform configuration (see Usage examples below)

## Usage

### AWS EKS with IRSA Example

This example shows a complete setup including EKS cluster creation and runner deployment.

```hcl
# Create VPC for EKS
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "platform-orchestrator-runner-vpc"
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

  cluster_name    = "platform-orchestrator-runner-cluster"
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

  role_name = "platform-orchestrator-runner-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["platform-orchestrator-kubernetes-agent-runner-job-ns:platform-orchestrator-kubernetes-agent-runner-job"]
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

# Deploy the Platform Orchestrator runner
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = var.orchestrator_org_id
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
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
  network_name = "platform-orchestrator-runner-network"

  subnets = [
    {
      subnet_name   = "platform-orchestrator-runner-subnet"
      subnet_ip     = "10.0.0.0/24"
      subnet_region = var.gcp_region
    }
  ]

  secondary_ranges = {
    platform-orchestrator-runner-subnet = [
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
  name       = "platform-orchestrator-runner-cluster"
  region     = var.gcp_region

  network           = module.gcp_network.network_name
  subnetwork        = module.gcp_network.subnets_names[0]
  ip_range_pods     = "gke-pods"
  ip_range_services = "gke-services"

  # Enable Workload Identity
  identity_namespace = "${var.project_id}.svc.id.goog"

  node_pools = [
    {
      name         = "platform-orchestrator-runner-pool"
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
  account_id   = "platform-orchestrator-runner"
  display_name = "Platform Orchestrator Kubernetes Agent Runner"
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

# Deploy the Platform Orchestrator runner
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
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
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
  # Runner pod runs here
  k8s_namespace     = "platform-orchestrator-runner-system"
  # Deployment jobs run here
  k8s_job_namespace = "platform-orchestrator-deployments"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/platform-orchestrator-runner-role"
  }
}
```

### With Unified Namespace

This example shows how to run both the runner pod and deployment jobs in the same namespace.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
  # Both runner and jobs use the same namespace
  k8s_namespace     = "platform-orchestrator-unified"
  k8s_job_namespace = "platform-orchestrator-unified"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/platform-orchestrator-runner-role"
  }
}
```

### With Custom Service Account Names

This example shows how to customize the service account names for both the runner and jobs.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
  # Service account for the runner pod
  k8s_service_account_name = "platform-orchestrator-runner-sa"
  # Service account for deployment jobs
  k8s_job_service_account_name = "platform-orchestrator-job-sa"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/platform-orchestrator-runner-role"
  }
}
```

### With Custom Runner ID

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"
  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
  runner_id        = "production-runner"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/platform-orchestrator-runner-role"
  }
}
```

### With Extra Environment Variables

This example shows how to pass additional environment variables to the kubernetes-agent runner pods.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
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
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/platform-orchestrator-runner-role"
  }
}
```

### With Custom Pod Template (Resource Limits)

This example shows how to customize the pod template for deployment jobs with resource limits and requests.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
  pod_template = jsonencode({
    metadata = {
      labels = {
        "app.kubernetes.io/name"    = "platform-orchestrator-runner"
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
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/platform-orchestrator-runner-role"
  }
}
```

### With Custom Pod Template (Node Selector and Tolerations)

This example shows how to use node selectors and tolerations to control pod placement.

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"

  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
  pod_template = jsonencode({
    metadata = {
      labels = {
        "app.kubernetes.io/name" = "platform-orchestrator-runner"
      }
    }
    spec = {
      nodeSelector = {
        "workload-type" = "platform-orchestrator-deployments"
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
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/platform-orchestrator-runner-role"
  }
}
```

### Minimal Configuration (No Cloud Provider Auth)

```hcl
module "kubernetes_agent_runner" {
  source = "github.com/stellwerk-tf-modules/kubernetes-agent-orchestrator-runner?ref=vX.Y.Z"

  orchestrator_org_id = "my-org-id"
  public_key_path  = "./runner_public_key.pem"
  nats_url                            = "tls://nats.orchestrator.example.com:4222"
  nats_existing_secret                = "runner-nats-creds"
  nats_job_credentials_existing_secret = "runner-nats-creds"
  create_namespaces                    = false
}
```

### Default `pod_template`:

```json
{
  "metadata": {
    "labels": {
      "app.kubernetes.io/name": "platform-orchestrator-runner"
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
3. **Helm Release**: Deploys the Platform Orchestrator Kubernetes agent runner chart from `oci://ghcr.io/stellwerk-labs/charts/platform-orchestrator-kubernetes-agent-runner`
4. **Platform Orchestrator Runner**: Registers the runner with Platform Orchestrator, configured to:
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
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0 |
| <a name="requirement_platform-orchestrator"></a> [platform-orchestrator](#requirement\_platform-orchestrator) | ~> 1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |
| <a name="provider_platform-orchestrator"></a> [platform-orchestrator](#provider\_platform-orchestrator) | 1.0.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.platform_orchestrator_kubernetes_agent_runner](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.platform_orchestrator_kubernetes_agent_runner_job](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [platform-orchestrator_kubernetes_agent_runner.my_runner](https://registry.terraform.io/providers/stellwerk-labs/platform-orchestrator/latest/docs/resources/kubernetes_agent_runner) | resource |
| [random_id.runner_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [local_file.agent_runner_public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_namespaces"></a> [create\_namespaces](#input\_create\_namespaces) | Create runner namespaces. Set false when pre-creating namespaces and externally managed NATS credential Secrets. | `bool` | `true` | no |
| <a name="input_extra_env_vars"></a> [extra\_env\_vars](#input\_extra\_env\_vars) | Additional environment variables to pass to the kubernetes-agent runner pods | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_humanitec_org_id"></a> [humanitec\_org\_id](#input\_humanitec\_org\_id) | Deprecated alias for orchestrator\_org\_id | `string` | `null` | no |
| <a name="input_k8s_job_namespace"></a> [k8s\_job\_namespace](#input\_k8s\_job\_namespace) | The Kubernetes namespace where the deployment jobs run | `string` | `"platform-orchestrator-kubernetes-agent-runner-job-ns"` | no |
| <a name="input_k8s_job_service_account_name"></a> [k8s\_job\_service\_account\_name](#input\_k8s\_job\_service\_account\_name) | The name of the Kubernetes service account to be assumed by the deployment jobs created by the kubernetes-agent runner | `string` | `"platform-orchestrator-kubernetes-agent-runner-job"` | no |
| <a name="input_k8s_namespace"></a> [k8s\_namespace](#input\_k8s\_namespace) | The Kubernetes namespace where the kubernetes-agent runner should run | `string` | `"platform-orchestrator-kubernetes-agent-runner-ns"` | no |
| <a name="input_k8s_service_account_name"></a> [k8s\_service\_account\_name](#input\_k8s\_service\_account\_name) | The name of the Kubernetes service account to be assumed by the the kubernetes-agent runner | `string` | `"platform-orchestrator-kubernetes-agent-runner"` | no |
| <a name="input_kubernetes_agent_runner_chart_repository"></a> [kubernetes\_agent\_runner\_chart\_repository](#input\_kubernetes\_agent\_runner\_chart\_repository) | Repository of the Kubernetes Agent Runner Helm chart (optional). Defaults to "oci://ghcr.io/stellwerk-labs/charts" | `string` | `"oci://ghcr.io/stellwerk-labs/charts"` | no |
| <a name="input_kubernetes_agent_runner_chart_version"></a> [kubernetes\_agent\_runner\_chart\_version](#input\_kubernetes\_agent\_runner\_chart\_version) | Version of the Kubernetes Agent Runner Helm chart | `string` | `"0.2.0"` | no |
| <a name="input_kubernetes_agent_runner_image_repository"></a> [kubernetes\_agent\_runner\_image\_repository](#input\_kubernetes\_agent\_runner\_image\_repository) | Kubernetes Agent Runner image without the tag, e.g. "my-registry.io/stellwerk/platform-orchestrator-runner" (optional). If omitted or set to an empty string (""), defaults to the value defined in the runner chart values.yaml file | `string` | `null` | no |
| <a name="input_kubernetes_agent_runner_image_tag"></a> [kubernetes\_agent\_runner\_image\_tag](#input\_kubernetes\_agent\_runner\_image\_tag) | Kubernetes Agent Runner image tag (optional). If omitted or set to an empty string (""), defaults to the value defined in the runner chart values.yaml file | `string` | `null` | no |
| <a name="input_nats_auth_type"></a> [nats\_auth\_type](#input\_nats\_auth\_type) | NATS authentication type: token or credentials | `string` | `"token"` | no |
| <a name="input_nats_ca_enabled"></a> [nats\_ca\_enabled](#input\_nats\_ca\_enabled) | Mount and use a private CA from the NATS credential Secrets | `bool` | `false` | no |
| <a name="input_nats_ca_key"></a> [nats\_ca\_key](#input\_nats\_ca\_key) | Key containing the NATS CA certificate in the credential Secrets | `string` | `"ca.crt"` | no |
| <a name="input_nats_credentials_key"></a> [nats\_credentials\_key](#input\_nats\_credentials\_key) | Key containing the NATS credentials file in the credential Secrets | `string` | `"creds"` | no |
| <a name="input_nats_existing_secret"></a> [nats\_existing\_secret](#input\_nats\_existing\_secret) | Secret in the runner namespace containing NATS credentials | `string` | `""` | no |
| <a name="input_nats_job_credentials_existing_secret"></a> [nats\_job\_credentials\_existing\_secret](#input\_nats\_job\_credentials\_existing\_secret) | Secret in the deployment Job namespace containing NATS credentials | `string` | `""` | no |
| <a name="input_nats_mode"></a> [nats\_mode](#input\_nats\_mode) | Runner transport mode: simple, edge, or airgap | `string` | `"simple"` | no |
| <a name="input_nats_token"></a> [nats\_token](#input\_nats\_token) | NATS token used for local/bootstrap installations. This value is stored in Terraform state; use externally managed Secrets in production. | `string` | `""` | no |
| <a name="input_nats_token_key"></a> [nats\_token\_key](#input\_nats\_token\_key) | Key containing the NATS token in the credential Secrets | `string` | `"token"` | no |
| <a name="input_nats_url"></a> [nats\_url](#input\_nats\_url) | NATS endpoint used by the runner. In airgap mode this is the protected-side broker. | `string` | n/a | yes |
| <a name="input_orchestrator_org_id"></a> [orchestrator\_org\_id](#input\_orchestrator\_org\_id) | The Platform Orchestrator organization ID to be set as a value in the Helm chart | `string` | `null` | no |
| <a name="input_pod_template"></a> [pod\_template](#input\_pod\_template) | A JSON-encoded pod template to customize the runner pods | `string` | `"{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"platform-orchestrator-runner\"}}}"` | no |
| <a name="input_public_key_path"></a> [public\_key\_path](#input\_public\_key\_path) | The path to the public key file for the kubernetes-agent runner | `string` | n/a | yes |
| <a name="input_runner_id"></a> [runner\_id](#input\_runner\_id) | The ID of the runner. If not provided, one will be generated using runner\_id\_prefix | `string` | `null` | no |
| <a name="input_runner_id_prefix"></a> [runner\_id\_prefix](#input\_runner\_id\_prefix) | The prefix to use when generating a runner ID. Only used if runner\_id is not provided | `string` | `"runner"` | no |
| <a name="input_service_account_annotations"></a> [service\_account\_annotations](#input\_service\_account\_annotations) | Annotations to add to the Kubernetes service account. Use this for cloud provider authentication (e.g., AWS IRSA role ARN or GCP Workload Identity service account). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_k8s_job_namespace"></a> [k8s\_job\_namespace](#output\_k8s\_job\_namespace) | The Kubernetes namespace where the deployment jobs are executed |
| <a name="output_k8s_job_service_account_name"></a> [k8s\_job\_service\_account\_name](#output\_k8s\_job\_service\_account\_name) | The name of the Kubernetes service account used by the deployment jobs |
| <a name="output_k8s_namespace"></a> [k8s\_namespace](#output\_k8s\_namespace) | The Kubernetes namespace where the runner is deployed |
| <a name="output_k8s_service_account"></a> [k8s\_service\_account](#output\_k8s\_service\_account) | The Kubernetes service account used by the runner |
| <a name="output_runner_helm_chart_version"></a> [runner\_helm\_chart\_version](#output\_runner\_helm\_chart\_version) | Helm chart version of the runner |
| <a name="output_runner_id"></a> [runner\_id](#output\_runner\_id) | The ID of the runner |
<!-- END_TF_DOCS -->
