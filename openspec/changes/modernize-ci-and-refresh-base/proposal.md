## Why

The CI pipeline is dead on arrival in Oct 2026: both `macos-12` runners are retired (`macos-14` dies Nov 2 2026), `windows-2019` is gone, `actions/checkout@v3` and `actions/upload-artifact@v3` run on the removed Node 20 runtime, and the runners now ship CMake 4.x, which hard-rejects `cmake_minimum_required(VERSION 2.8)` in `CMakeLists.txt`. The LLVM provisioning is equally dead (an Ubuntu 18.04 LLVM 9 tarball, a hand-made LLVM 9 Windows zip, and a `brew install llvm@14` whose bottles stop at macOS Sonoma). At the same time the source base is two years stale — Faust pinned at 2.54.9, Pd at 0.53-1 — and two upstream PRs (`agraef/pd-faustgen` #4 submodule bumps, #5 JIT factory teardown at exit) sit unmerged, the latter being the known fix for the teardown crash the local build exhibits. The goal is a build that loads warning- and crash-free on a local immutable Linux machine, plus a manually runnable 3-platform workflow (macOS arm64, Linux x64, Windows x64) that stays inside the free GitHub plan for public repositories.

## What Changes

- Integrate upstream PR `agraef/pd-faustgen#5` (register `atexit(deleteAllCDSPFactories)` after the first JIT factory is created) so DSP factories are torn down before libfaust's static destructors run.
- Integrate the intent of upstream PR `#4` (refresh submodules), superseding its pins with current ones: `faust` → release tag **2.88.0** (`8c00913`), `pure-data` → current master head (0.56-5 or later), `pd.build` already at head (no-op). Faust 2.88.0 carries the "build against LLVM 23" fix, which is what allows stock LLVM on Linux and macOS.
- **BREAKING**: raise `cmake_minimum_required` in `CMakeLists.txt` from `2.8` to `3.5`, without which nothing configures under the CMake 4.x that runners now ship.
- Rewrite `.github/workflows/makefile.yml`: three build jobs only — `macos-15` (arm64), `ubuntu-24.04` (x64), `windows-2025` (x64) — dropping the macOS Intel cross-compile job and its hand-rolled LLVM 14 zip entirely.
- Add `workflow_dispatch` so the full matrix can be run manually, alongside the existing `push`/`tags` triggers.
- Replace every dead runner/action/LLVM reference: `checkout@v5`, `upload-artifact@v4`/`download-artifact@v4`, and per-platform LLVM provisioning (Homebrew `llvm` on macOS, `apt` llvm packages on Ubuntu, and on Windows a SHA-256-pinned LLVM 17 archive from the Faust project's own release assets — the same one `grame-cncm/faust`'s CI uses — replacing both the defective runner-image LLVM and the old LLVM 9/14 downloads).
- Keep the staged-install layout and artifact contents as they are today (`faustgen2~` folder + README + LICENSE + read-only `default.dsp`), with explicit artifact retention sized to the free plan's storage allowance.

## Capabilities

### New Capabilities

- `ci-pipeline`: The GitHub Actions workflow — what triggers it (manual dispatch, branch pushes, tags), which three platform jobs it runs, what artifacts each produces and for how long they are retained, and how tagged builds become draft releases.
- `build-system`: How the external is built from the pinned submodule sources — toolchain floors (CMake ≥ 3.5, LLVM version support), per-platform LLVM discovery, the staged install layout, and the pinned dependency versions the build must succeed against.
- `external-lifecycle`: How the built external behaves when loaded into Pd — it loads without warnings, compiles and plays a dsp, and shuts down without crashing when Pd exits.

### Modified Capabilities

(none — this repository has no existing specs)

## Impact

- **Files**: `.github/workflows/makefile.yml` (full rewrite), `CMakeLists.txt` (minimum version), `src/faustgen_tilde.c` (PR #5, ~7 lines), `.gitmodules` gitlinks for `faust` and `pure-data`.
- **Dependencies**: Faust 2.54.9 → 2.88.0 (large jump: library and JIT backend changes), Pd headers 0.53-1 → 0.56-x. `pd.build` unchanged.
- **Downstream**: release artifacts keep their names and layout, so Deken/OBS packaging and existing install docs stay valid; anyone building with CMake older than 3.5 can no longer configure (not a practical audience).
- **Not affected**: `debuild/` packaging, `deken/` scripts, patches and docs, `make-dist.sh` (verified against the new workflow during apply).
- **Local machine**: consumes the Linux x64 CI artifact — it does not build from source.
