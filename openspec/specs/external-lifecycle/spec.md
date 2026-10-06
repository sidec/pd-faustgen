# external-lifecycle Specification

## Purpose
Defines how the built faustgen2~ external behaves inside Pure Data: clean loading, working on-the-fly Faust compilation, and a crash-free shutdown.

## Requirements

### Requirement: Loads without warnings
Loading the external into Pure Data (0.55 or later) SHALL not produce warnings or errors on the Pd console — no missing-symbol, missing-library, or API-mismatch messages.

#### Scenario: Load on startup
- **WHEN** Pd is started with `faustgen2~` in the startup libraries (or `declare -lib faustgen2~` is used)
- **THEN** the external loads and the Pd console shows no warning or error attributable to it

#### Scenario: Load the help patch
- **WHEN** the shipped `faustgen2~-help.pd` is opened
- **THEN** every object in the patch resolves and no console warnings appear

### Requirement: Compiles and plays a Faust program
The external SHALL compile a loaded `.dsp` file with the LLVM JIT and produce audio output, and SHALL remain usable for repeated recompiles within one Pd session.

#### Scenario: First compile
- **WHEN** `faustgen2~` is created with a dsp name and audio is running
- **THEN** the JIT compiles the program and the object produces the expected signal on its outlets

#### Scenario: Recompile in the same session
- **WHEN** the dsp source is edited and recompiled while Pd keeps running
- **THEN** the new program is compiled and played without restarting Pd

### Requirement: Clean shutdown
Quitting Pure Data with one or more DSP factories alive SHALL terminate normally: all Faust DSP factories are destroyed before libfaust's static destructors run, and no crash, abort, or static-destruction-order fault occurs at exit.

#### Scenario: Quit after compiling
- **WHEN** Pd is quit after at least one dsp has been JIT-compiled
- **THEN** Pd exits with status 0 and no crash report is generated

#### Scenario: Quit after repeated recompiles
- **WHEN** Pd is quit after several recompiles in the same session
- **THEN** exit remains clean and no factory teardown fault occurs

### Requirement: Verified on a local immutable Linux machine
The Linux x64 artifact produced by CI SHALL, when installed into a Pd external search path on the target immutable Linux machine, satisfy the load, compile, and shutdown requirements above with no warnings and no crashes.

#### Scenario: Install CI artifact locally
- **WHEN** the `pd-faustgen2-<version>-ubuntu-x86_64` artifact is downloaded from a CI run and its `faustgen2~` folder is placed on the Pd external search path
- **THEN** loading, compiling, and quitting behave as specified in the preceding requirements
