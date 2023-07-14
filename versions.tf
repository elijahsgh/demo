terraform {
  required_providers {
    kubernetes = {
      version = "= 2.22.0"
    }

    helm = {
      version = "= 2.10.1"
    }

    harness = {
      source  = "harness/harness"
      version = "= 0.23.0"
    }
  }
}