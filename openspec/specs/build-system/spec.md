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

### Requirement: Configures under modern CMake
The top-level build SHALL declare a minimum CMake version of 3.5 or later, so that configuration succeeds with CMake 4.x as shipped by current CI runners and package repositories.

#### Scenario: Configure with CMake 4.x
- **WHEN** `cmake ..` is run with a CMake 4.x binary
- **THEN** configuration completes without a policy/compatibility error about the declared minimum version

#### Scenario: Configure with CMake 3.5+
- **WHEN** `cmake ..` is run with any CMake from 3.5 up
- **THEN** configuration completes successfully

### Requirement: Builds against pinned bundled sources
The build SHALL compile against the repository's git submodules: Faust pinned at release 2.88.0, Pure Data pinned at a specific commit of its master branch, and `pd.build` pinned at its head. The build SHALL NOT require a pre-installed Faust or Pd.

#### Scenario: Clean recursive clone builds
- **WHEN** the repository is cloned with `--recurse-submodules` and built with default options
- **THEN** the bundled Faust static library and the external compile and link without any system Faust installation present

#### Scenario: Faust version in use is 2.88.0
- **WHEN** the build configures the bundled Faust
- **THEN** the reported Faust version is 2.88.0

### Requirement: Uses platform-provided LLVM
The build SHALL use an LLVM installation supplied by the platform's package manager or the CI runner image, except on Windows: because the runner image's LLVM installation is defective upstream (an install without `llvm-config` or the LLVM CMake modules), the Windows job SHALL use a prebuilt LLVM archive pinned to an immutable release asset of the vendored Faust project (grame-cncm/faust) and verified against a pinned SHA-256 checksum before use. No build SHALL depend on end-of-life LLVM releases (9.x) or on building LLVM from source.

#### Scenario: Linux
- **WHEN** the Linux job builds the external
- **THEN** LLVM comes from the distribution's packages and the build finds its CMake configuration

#### Scenario: macOS
- **WHEN** the macOS job builds the external
- **THEN** LLVM comes from Homebrew's current LLVM formula and the build finds its CMake configuration

#### Scenario: Windows
- **WHEN** the Windows job builds the external
- **THEN** LLVM comes from the pinned, checksum-verified faust-project prebuilt archive, extracted with the runner's `7z`, and the build finds its CMake configuration, including `llvm-config` and the LLVM CMake modules

### Requirement: Staged install layout
The install step SHALL produce a single `faustgen2~` folder containing the platform's external binary (`faustgen2~.pd_darwin`, `faustgen2~.pd_linux`, or `faustgen2~.dll`), `README.md`, `LICENSE`, and a `default.dsp` made read-only.

#### Scenario: Staged contents
- **WHEN** the install step runs into a staging prefix
- **THEN** the `faustgen2~` folder contains the external binary, README, LICENSE, and a read-only `default.dsp`

#### Scenario: macOS dynamic libraries resolve
- **WHEN** the macOS external is produced with Homebrew LLVM
- **THEN** every non-system dylib it references is bundled next to the external and its install names point at `@loader_path`, so the folder is self-contained

### Requirement: Native 64-bit binaries only
Builds SHALL target the 64-bit architecture of each platform: arm64 on macOS, x86_64 on Linux and Windows.

#### Scenario: Architecture of outputs
- **WHEN** the three artifacts are inspected
- **THEN** the macOS binary is arm64, and the Linux and Windows binaries are x86_64
