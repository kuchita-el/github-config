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
  # TODO(setup): replace the organization below with your HCP Terraform organization name.
  # See README.md "初期セットアップ" for how to create the org and workspace.
  cloud {
    organization = "REPLACE_WITH_YOUR_HCP_ORG"

    workspaces {
      name = "github-config"
    }
  }
}
