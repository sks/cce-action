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

Binaries are downloaded from [releases.stackgen.com](https://releases.stackgen.com/binaries/cce/) (default version `0.0.5`).

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

The step installs CCE, runs a scan, uploads `cce-report.json` as an artifact, and sets `entitlement-count` output.

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
| `version` | `0.0.5` | CCE release (no leading `v`) |
| `folder` | `.` | Directory to scan |
| `language` | `GO` | `GO`, `JAVA`, `AUTO`, … |
| `filter` | `cloud` | `cloud` or `all` |
| `format` | `json` | `json`, `text`, or `sarif` |
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

## Related

- [CCE docs](https://appcd-dev.github.io/cce/)
- [Homebrew install](https://github.com/stackgenhq/homebrew-stackgen)
- [Blog walkthrough (external-dns)](https://sks.github.io/blog/cce-cloud-entitlements/)

## License

Apache-2.0
