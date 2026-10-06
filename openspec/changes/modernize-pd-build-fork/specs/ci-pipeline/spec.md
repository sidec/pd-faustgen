## Purpose

Defines the jobs, triggers, and artifacts of the pd-faustgen CI pipeline, including how the Windows job obtains the Pd import library it links against.

## ADDED Requirements

### Requirement: Windows job links the vendored import library

The Windows build job SHALL link the Pd import library from the `pd.build` submodule checkout and SHALL NOT download, parse, or derive Pd import libraries during pd-faustgen CI.

#### Scenario: no Pd binary download in pd-faustgen CI

- **WHEN** the Windows job runs
- **THEN** no step fetches Pd binaries from msp.ucsd.edu or invokes `lib.exe` to create an import library, and the build links `pd.build/x64/pd.lib` via the pd.build CMake defaults

#### Scenario: stale pin fails loudly

- **WHEN** the vendored import library lacks a symbol referenced by the compiled sources
- **THEN** the link step fails with an unresolved external symbol error naming that symbol

### Requirement: Fork library refresh is independent of pd-faustgen CI

Regeneration of the vendored import libraries SHALL happen in the `sidec/pd.build` fork's own CI, not in the pd-faustgen pipeline.

#### Scenario: pd-faustgen dispatch stays green without derivation steps

- **WHEN** the pd-faustgen workflow is dispatched with `windows_only=true`
- **THEN** the Windows job goes green using only repository and submodule content plus the pinned LLVM archive
