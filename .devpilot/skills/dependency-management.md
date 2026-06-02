# Dependency Management — own your supply chain

Load this **before adding a new dependency or upgrading existing ones.** Most of your code is
code you didn't write; a dependency is a long-term liability, not a free win.

## Before you add one
- **Justify it.** Could a few lines of your own replace it? Tiny/trivial deps add supply-chain
  surface for little gain.
- **Vet it** — maintained (recent commits/releases), healthy adoption, sane transitive tree,
  no known critical CVEs, compatible **license** (no copyleft surprises in proprietary code).
- Prefer the standard library and well-established packages over novelty.

## Keep it healthy
- **Pin & lock** — commit the lockfile; reproducible builds across machines and CI.
- **Scan continuously** — dependency vulnerability scan in CI (see `ci-cd`); a critical CVE
  blocks the build. Automate update PRs (Dependabot/Renovate) so upgrades are small and frequent,
  not a yearly cliff.
- **Update deliberately** — read changelogs for breaking changes; upgrade in its own PR with tests green.
- **Remove** what you no longer use; dead dependencies are unscanned risk.

## Ship-with
- [ ] New dep justified, maintained, license-compatible, no critical CVE.
- [ ] Lockfile updated/committed; dependency scan passes in CI.
- [ ] Upgrades isolated in their own PR (see `version-control`); unused deps pruned.
