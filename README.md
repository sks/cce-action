# cce-action

GitHub Action to scan source code for **cloud SDK usage** with [CCE](https://github.com/appcd-dev/cce) (Code Context Engine).

Drop it into any workflow — same pattern as `actions/checkout`:

```yaml
- uses: sks/cce-action@v1
  with:
    folder: provider/aws
    language: GO
```

CCE maps SDK call sites to `(provider, resource, operation)` tuples so you can derive IAM actions, audit cloud surface, and gate PRs that add new permissions.

Runs CCE from the published container image [`ghcr.io/stackgenhq/cce`](https://github.com/stackgenhq/homebrew-stackgen/pkgs/container/cce) (default tag `0.0.5`). No tarball downloads.

## Quick start

```yaml
name: Cloud entitlements

on:
  pull_request:
  push:
    branches: [main]

jobs:
  cce:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sks/cce-action@v1
        with:
          folder: .
          language: GO
          filter: cloud
```

The step pulls `ghcr.io/stackgenhq/cce`, runs a scan, uploads `cce-report.json` as an artifact, and sets `entitlement-count` output.

## PR gate: fail on new entitlements

Scan `main` as baseline, then diff the PR branch:

```yaml
jobs:
  cce:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Baseline scan (main)
        uses: sks/cce-action@v1
        with:
          folder: provider/aws
          output: baseline.json
          upload-artifact: false

      - uses: actions/checkout@v4
        with:
          ref: ${{ github.head_ref }}

      - name: PR scan + diff
        uses: sks/cce-action@v1
        with:
          folder: provider/aws
          output: pr.json
          baseline: baseline.json
          fail-on-new: true
```

See [examples/pr-diff-gate.yml](examples/pr-diff-gate.yml) for a complete workflow.

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `version` | `0.0.5` | Image tag for `ghcr.io/stackgenhq/cce` |
| `image` | *(auto)* | Full image ref (overrides `version`) |
| `mode` | `scan` | `scan` or `run` (`cce run -pack` / `-recipes`) |
| `folder` | `.` | Directory to scan |
| `language` | `GO` | `GO`, `JAVA`, `AUTO`, … |
| `filter` | `cloud` | `cloud` or `all` (scan mode; use `all` for custom lens providers) |
| `format` | `json` | `json`, `text`, or `sarif` (scan mode) |
| `mapper-file` | *(empty)* | Lens YAML path or HTTPS URL (scan mode) |
| `pack` | *(empty)* | Recipe pack id (run mode) |
| `recipes` | *(empty)* | Comma-separated recipe ids (run mode, alternative to `pack`) |
| `remote` | `false` | Fetch catalog from releases.stackgen.com (run mode) |
| `catalog-url` | *(empty)* | Override `catalog.json` URL (run mode, enterprise) |
| `packs-url` | *(empty)* | Override `packs.json` URL (run mode, enterprise) |
| `output` | `cce-report.json` | Report file path |
| `baseline` | *(empty)* | Baseline JSON for `cce diff` |
| `fail-on-new` | `true` | Fail when diff finds new entitlements |
| `policy` | *(empty)* | Optional YAML governance policy |
| `diff-output` | `cce-diff.json` | Diff report path |
| `upload-artifact` | `true` | Upload report(s) as artifacts |
| `artifact-name` | `cce-entitlements` | Artifact name prefix |

## Outputs

| Output | Description |
|--------|-------------|
| `report-path` | Path to the scan report |
| `entitlement-count` | `summary.total_entitlements` (JSON scans) |
| `diff-path` | Path to diff JSON when `baseline` is set |

## Derive IAM actions from the report

```bash
jq -r '.entitlements[]
  | select(.provider == "AWS")
  | "\(.resource):\(.operation)"' cce-report.json | sort -u
```

Wire the action list into Terraform, IRSA, or your policy generator. Resource ARNs stay in IaC.

## Custom lenses (Path A)

Point at a lens YAML in your repo or on internal HTTPS — same as `-mapper-file` in the [enterprise lenses guide](https://github.com/appcd-dev/cce/blob/main/docs/guides/enterprise-lenses-and-catalogs.md):

```yaml
- uses: sks/cce-action@v1
  with:
    folder: .
    language: AUTO
    filter: all          # required for PLATFORM / TECH_DEBT / FORBIDDEN providers
    mapper-file: https://artifacts.corp.example/cce/lenses/idp/v1.2.0/idp_lenses.yaml
    output: idp-inventory.json
```

Your lens runs **first**; built-in cloud rules fill gaps when the lens does not match. Pin versioned URLs in CI (`/v1.2.0/`, not only `latest`).

See [examples/custom-lens.yml](examples/custom-lens.yml).

## Recipe packs and catalogs (Path B)

Run multiple recipes in **one parse** via `cce run -pack` or `-recipes`:

```yaml
# Public StackGen catalog
- uses: sks/cce-action@v1
  with:
    mode: run
    pack: modernization-pack
    remote: true
    output: modernization.json
```

```yaml
# Self-hosted enterprise catalog
- uses: sks/cce-action@v1
  with:
    mode: run
    pack: corp-platform-pack
    catalog-url: https://artifacts.corp.example/cce/recipes/latest/catalog.json
    packs-url: https://artifacts.corp.example/cce/recipes/latest/packs.json
    output: platform.json
```

| `mode` | When to use |
|--------|-------------|
| `scan` (default) | Built-in cloud mapping, optional `-mapper-file` lens |
| `run` | Catalog recipes / packs — cloud + IDP inventory merged |

Combine either mode with `baseline` + `policy` + `fail-on-new` to gate forbidden internal libraries or new cloud APIs.

See [examples/enterprise-pack.yml](examples/enterprise-pack.yml) and [examples/public-modernization-pack.yml](examples/public-modernization-pack.yml).

## Container image reference

The action uses:

```text
docker pull ghcr.io/stackgenhq/cce:0.0.5
# or
docker pull ghcr.io/stackgenhq/cce:latest
```

Override in workflows:

```yaml
- uses: sks/cce-action@v1.2.0
  with:
    version: latest
    # or pin an explicit ref:
    # image: ghcr.io/stackgenhq/cce@sha256:02520efc4071dd7a0940fbbefd77def2cc3f069c84cf5e0ea498f6aea64f254f
```

To run CCE as the job container (no composite action), see [examples/docker-container-job.yml](examples/docker-container-job.yml).

## Related

- [Enterprise lenses and catalogs](https://github.com/appcd-dev/cce/blob/main/docs/guides/enterprise-lenses-and-catalogs.md)
- [CCE docs](https://appcd-dev.github.io/cce/)
- [CCE container package](https://github.com/stackgenhq/homebrew-stackgen/pkgs/container/cce)
- [Homebrew install](https://github.com/stackgenhq/homebrew-stackgen)
- [Blog walkthrough (external-dns)](https://sks.github.io/blog/cce-cloud-entitlements/)

## License

Apache-2.0
