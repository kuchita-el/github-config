locals {
  # ---------------------------------------------------------------------------
  # Tag-protection profile defaults: per-profile enforcement (ADR 0004 §4・§7,
  # ADR 0009), keyed by every profile identifier with the same attribute set in
  # each row. Only "distribution" repos ship version tags that outside users
  # reference as refs (`uses: owner/repo@vX.Y.Z` 等); "infra" / "app" /
  # "local_config" repos have no such external reference surface today, so
  # protection starts disabled for them (ADR 0009 決定 §1). They cannot be
  # changed per repository; deviating a repository requires registering the
  # attribute in the README exception ledger (ADR 0004 §4).
  # ---------------------------------------------------------------------------
  tag_protection_profile_defaults = {
    distribution = {
      enforcement = "active"
    }
    infra = {
      enforcement = "disabled"
    }
    app = {
      enforcement = "disabled"
    }
    local_config = {
      enforcement = "disabled"
    }
  }

  # ---------------------------------------------------------------------------
  # Tag-protection preset: all-repository common values (ADR 0004 §4, ADR 0009
  # 決定 §1・§2). Protects release-specific version tags (vX.Y.Z) only; floating
  # tags such as v1 / v1.1 are intentionally excluded because
  # dependabot-triage-action's release.yml force-moves them per GitHub's
  # documented immutable-release convention (ADR 0009 コンテキスト). Creation is
  # left unrestricted (no `creation` rule declared) and no bypass actor is
  # granted. They cannot be changed per repository; deviating a repository
  # requires registering the attribute in the README exception ledger
  # (ADR 0004 §4).
  # ---------------------------------------------------------------------------
  tag_protection_preset = {
    name   = "tag protection"
    target = "tag"

    # fnmatch (GitHub Docs "Creating rulesets for a repository"): `*` does not
    # cross `/` (File::FNM_PATHNAME), and `.` is a literal character. This
    # pattern requires two literal dots after "v", so it matches "v1.0.0" but
    # not "v1" (no dot) or "v1.1" (only one dot) — see ADR 0009 根拠.
    ref_include = ["refs/tags/v*.*.*"]
    ref_exclude = []

    deletion         = true
    update           = true
    non_fast_forward = true
  }

  # ---------------------------------------------------------------------------
  # Tag-protection targets: public repositories only, since the GitHub Free
  # plan allows Rulesets on public repositories only (ADR 0004 §6). Profile is
  # not used to narrow this target set; disabled profiles are represented as
  # enforcement = "disabled" instances instead (ADR 0009 決定 §1, Issue #74 Q2).
  # ---------------------------------------------------------------------------
  tag_protection_targets = {
    for repo, cfg in var.repositories : repo => cfg if cfg.visibility == "public"
  }
}

# Tag protection (Repository Ruleset) for every public managed repository.
# One ruleset per repo, expanded with for_each keyed by repository name so that
# adding/removing a repo never recreates the others.
# All-repository common values come from local.tag_protection_preset;
# per-profile enforcement comes from local.tag_protection_profile_defaults keyed
# by var.repositories[<repo>].profile (ADR 0004 §4・§7, ADR 0009). No repo-
# specific values exist for this concern, so `repositories.<k>.tag_protection`
# is not introduced (ADR 0009 代替案).
resource "github_repository_ruleset" "tag_protection" {
  for_each = local.tag_protection_targets

  name        = local.tag_protection_preset.name
  repository  = each.key
  target      = local.tag_protection_preset.target
  enforcement = local.tag_protection_profile_defaults[each.value.profile].enforcement

  conditions {
    ref_name {
      include = local.tag_protection_preset.ref_include
      exclude = local.tag_protection_preset.ref_exclude
    }
  }

  rules {
    deletion         = local.tag_protection_preset.deletion
    update           = local.tag_protection_preset.update
    non_fast_forward = local.tag_protection_preset.non_fast_forward
  }
}
