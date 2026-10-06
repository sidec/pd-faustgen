# build-system Specification

## Purpose
Defines where the build sources its pinned third-party inputs, including the Pd import libraries the external links against on Windows.

## Requirements

### Requirement: pd.build submodule sourced from the maintained fork

The `pd.build` submodule SHALL be sourced from `https://github.com/sidec/pd.build.git`, and its pin SHALL be a fork commit that carries regenerated import libraries.

#### Scenario: submodule URL points at the fork

- **WHEN** `.gitmodules` is inspected
- **THEN** the `pd.build` entry's URL is `https://github.com/sidec/pd.build.git`

#### Scenario: pin carries regenerated libraries

- **WHEN** the pinned fork commit is checked out
- **THEN** `pd.build/x64/pd.def` contains the `pdgui_vmess` export and `pd.build/x64/pd.lib` and `pd.build/x86/pd.lib` exist

### Requirement: Vendored import libraries track official Pd releases

The vendored `x64` and `x86` `pd.lib`/`pd.def` pairs SHALL be derived from the official Pd Windows binaries of the same version as the `pure-data` submodule pin, for both architectures.

#### Scenario: libraries match the pure-data pin

- **WHEN** the `pure-data` submodule pins Pd version V
- **THEN** the vendored import libraries are generated from Pd version V's official Windows binaries for x86_64 and i386

#### Scenario: regeneration is reproducible from pinned inputs

- **WHEN** the regeneration recipe is re-run against the pinned URLs and SHA-256 checksums
- **THEN** it produces export definitions identical to the committed ones (barring an upstream binary change, which changes the pinned checksum)
