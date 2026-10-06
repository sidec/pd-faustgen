## Purpose

Defines how the pd-faustgen2~ GitHub Actions pipeline is triggered, which platform jobs it runs, and what build artifacts and releases it produces for consumers.

## ADDED Requirements

### Requirement: Manual full-matrix dispatch
The workflow SHALL support `workflow_dispatch` so a maintainer can run the complete build matrix manually on demand, from any branch, without pushing a commit.

#### Scenario: Manual run from the Actions UI
- **WHEN** a maintainer triggers the workflow manually via `workflow_dispatch`
- **THEN** all platform build jobs run and each uploads its artifact

#### Scenario: Manual run from the CLI
- **WHEN** the workflow is triggered with `gh workflow run` against a chosen ref
- **THEN** the run executes on that ref and produces the same artifacts as a push-triggered run

### Requirement: Automatic triggers on pushes and tags
The workflow SHALL continue to run on pushes to the mainline branches and on tag pushes, and SHALL NOT run on pull requests from forks in a way that consumes maintainer-only secrets (none are used).

#### Scenario: Push to mainline
- **WHEN** a commit is pushed to a tracked branch
- **THEN** the build matrix runs and uploads artifacts

#### Scenario: Tag push
- **WHEN** a tag is pushed
- **THEN** the build matrix runs and, on success, a draft prerelease is created containing the zipped artifacts

### Requirement: Exactly three platform jobs
The workflow SHALL define build jobs for macOS arm64, Linux x64, and Windows x64 only, on currently supported runner images. There SHALL be no macOS Intel (x86_64) job.

#### Scenario: Supported runner images
- **WHEN** the workflow is inspected
- **THEN** it references only runner labels that are supported at run time (no retired images such as `macos-12`, `macos-14`, or `windows-2019`) and no action versions running on removed Node runtimes (no `actions/checkout@v3`, no `actions/*-artifact@v3`)

#### Scenario: Three artifacts per run
- **WHEN** a full run completes successfully
- **THEN** exactly one artifact exists for each of `macos-arm64`, `ubuntu-x86_64`, and `windows-x86_64`

### Requirement: Consistent versioned artifact names
Each job SHALL publish its artifact under the name `pd-faustgen2-<version>-<platform>`, where `<version>` comes from `git describe` on a full-history checkout, and `<platform>` is one of `macos-arm64`, `ubuntu-x86_64`, `windows-x86_64`.

#### Scenario: Versioned artifact naming
- **WHEN** a run on a tag (or any commit reachable from a tag) completes
- **THEN** artifact names carry the `git describe` version, e.g. `pd-faustgen2-2.2.0-1-gabc1234-ubuntu-x86_64`

#### Scenario: History-dependent version
- **WHEN** the workflow checks out the repository
- **THEN** it fetches full history so `git describe` can resolve tags

### Requirement: Artifact retention within the free plan
Artifacts SHALL be retained for a short, explicitly configured period so that repeated runs stay within the free plan's shared artifact storage allowance.

#### Scenario: Retention is configured
- **WHEN** any upload-artifact step runs
- **THEN** it sets an explicit `retention-days` value rather than relying on the platform default

### Requirement: Releases are draft and prerelease
Tag-triggered releases SHALL be created as drafts marked as prereleases, and SHALL bundle every platform artifact plus the source tarball into downloadable zip archives.

#### Scenario: Draft release on tag
- **WHEN** a tag build succeeds
- **THEN** a draft prerelease exists whose assets include one zip per platform artifact and the source tarball
