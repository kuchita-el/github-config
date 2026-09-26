terraform {
  # optional() with defaults in object types requires >= 1.3; cloud {} is stable since 1.1.
  required_version = ">= 1.6"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Remote state + remote execution on HCP Terraform (formerly Terraform Cloud), free tier.
  cloud {
    organization = "kuchita-el"

    workspaces {
      name = "github-config"
    }
  }
}
