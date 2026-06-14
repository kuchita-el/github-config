provider "github" {
  owner = var.github_owner

  # Authentication: the provider reads the token from the GITHUB_TOKEN environment
  # variable. Under HCP Terraform Remote execution this is supplied by a *sensitive*
  # workspace environment variable named GITHUB_TOKEN (a fine-grained PAT with
  # Administration: Read and Write on the managed repositories).
  # Never hardcode the token here. See README.md "初期セットアップ".
}
