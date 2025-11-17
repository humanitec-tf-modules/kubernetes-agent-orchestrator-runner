terraform {
  required_version = ">= 1.6.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    platform-orchestrator = {
      source  = "humanitec/platform-orchestrator"
      version = "~> 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3"
    }
    # Provider for installing K8s objects for the runner
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
    # Provider for reading key files
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}
