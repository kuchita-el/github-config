provider "github" {
  owner = var.github_owner

  # Authentication: GitHub App installation. The provider mints short-lived
  # installation tokens from three *sensitive* workspace environment variables
  # injected by HCP Terraform under Remote execution:
  #   GITHUB_APP_ID              - the App's identifier
  #   GITHUB_APP_INSTALLATION_ID - the App installation on this account
  #   GITHUB_APP_PEM_FILE        - the App private key *contents* (not a path; \n for newlines)
  # The empty app_auth block is required so the provider reads those env vars
  # (terraform-plugin-sdk#142). `owner` above is mandatory under App auth
  # (without it: 403 "Resource not accessible by integration").
  # App scope: installed on selected repositories only; permissions limited to
  # Administration: Read and write + Metadata: Read (no Contents). See README.md.
  # Never hardcode the PEM here (the repo is public; push protection is on).
  # Rollback: re-add the GITHUB_TOKEN (PAT) env var and revert this app_auth
  # block to fall back to token authentication.
  app_auth {}
}
