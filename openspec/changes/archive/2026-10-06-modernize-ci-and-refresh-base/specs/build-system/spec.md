## Purpose

Defines how the faustgen2~ external is configured and built: the toolchain floors it must satisfy, where LLVM comes from, which pinned dependency sources it must compile against, and the layout of the staged installation it produces.

## ADDED Requirements

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
