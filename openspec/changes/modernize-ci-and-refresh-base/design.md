## Context

`sidec/pd-faustgen` `faustgen2` is byte-identical to `agraef/pd-faustgen` `faustgen2` (verified: compare API reports `status: identical`), so it is a clean base for the two open upstream PRs. The current workflow (`.github/workflows/makefile.yml`) and the toolchain assumptions inside `CMakeLists.txt` date from 2024 and are incompatible with today's runners — see proposal.md for the failure inventory. Facts this design leans on:

- Actions minutes are **free and unlimited for public repositories** (GitHub billing docs, verified Oct 2026); `sidec/pd-faustgen` is public, so macOS runners cost nothing.
- Runner landscape Oct 2026: `macos-15` (arm64) and `macos-26` are current; `macos-14` retires Nov 2 2026; `macos-12`/`windows-2019` are gone. `ubuntu-24.04` and `windows-2025` (VS 2026) are current.
- Runners ship **CMake 4.x** (Windows image: 4.3.4), which hard-errors on `cmake_minimum_required(VERSION < 3.5)`.
- Homebrew still ships `llvm@14`…`llvm@23`, but `llvm@14` bottles stop at macOS Sonoma → unusable on arm64 runners without a source build. Ubuntu 24.04 apt ships LLVM 14–20. Windows images claim LLVM 20.1.8 but ship a defective install (fingerprint: no `llvm-config`, no LLVM CMake modules; upstream issue actions/runner-images #14260).
- Faust 2.88.0's changelog includes "Fix build against LLVM 23", i.e. current Faust tracks current LLVM.
- `tests/` already contains Pd patches for load, recompile, and double-precision checks — usable as acceptance probes.

## Goals / Non-Goals

**Goals:**
- Fold upstream PRs #4 (submodule refresh, superseded) and #5 (JIT teardown) into the base.
- One workflow, three jobs (macOS arm64, Linux x64, Windows x64), manually runnable via `workflow_dispatch`, free on the public plan.
- Stock LLVM on Linux and macOS; on Windows, the Faust project's own pinned, SHA-256-verified prebuilt LLVM archive — never end-of-life, never from source.
- Linux x64 artifact loads warning- and crash-free on the local immutable Linux machine.

**Non-Goals:**
- macOS Intel / x86_64 builds (explicitly dropped; `macos-15-intel`/`macos-26-intel` remain available if ever needed).
- Migrating CI to GitLab (unnecessary: public-repo GitHub minutes are free and unlimited).
- Building from source on the local machine — it consumes CI artifacts only.
- Deken/OBS packaging changes, `debuild/`, `deken/`, `make-dist.sh` rework (only verified, not modified).
- Supporting CMake older than 3.5 or Pd older than 0.55.

## Decisions

**D1 — Faust pinned to release tag 2.88.0 (`8c00913`), not `master-dev` head.**
Chosen by user. Rationale: 2.88.0 is the newest *released* Faust, includes the LLVM 23 build fix, and is an immutable pin — `master-dev` (2.90.3-dev) would move every time grame pushes, making CI runs irreproducible. Alternative considered: PR #4's 2.83.1 (smaller jump, but misses 2.85–2.88 fixes including the LLVM fix that this design depends on).

**D2 — Integrate PR #5 by applying its 7-line patch verbatim; PR #4 is superseded, not merged.**
PR #4 only bumps two gitlinks to revisions (2.83.1 / 0.56-2) that we immediately replace with newer pins, so cherry-picking it buys nothing but a misleading history. Its *intent* (refresh submodules) is carried out with current revisions. PR #5's content (`atexit(deleteAllCDSPFactories)` registered after the first JIT factory exists, in `faustgen_tilde.c` near the `f_dsp_instance` assignment) is applied as-is — it is the upstream-authored fix for the shutdown crash.

**D3 — LLVM per platform, located the same way in all three jobs: `-DLLVM_DIR` pointing at the provider's CMake config.**
- Linux: `apt-get install llvm-dev` (or a versioned `llvm-XX-dev`) on `ubuntu-24.04`.
- macOS: `brew install llvm`, `LLVM_DIR=$(brew --prefix llvm)/lib/cmake/llvm`.
- Windows: the runner image's LLVM is defective (fingerprint: 481 files, no `llvm-config.exe`, no `LLVMConfig.cmake`; upstream issue actions/runner-images #14260), and the VS-bundled Clang toolset ships neither (probed: no `llvm-config.exe`/`LLVMConfig.cmake` anywhere in the VS trees). Use instead `grame-cncm/faust`'s `llvm-17.0.6-win11-x86_64.zip` — the archive their own `libfaust.yml` Windows CI uses — SHA-256-pinned as an immutable release asset, `7z`-extracted, with `llvm-config` on `PATH`.
Alternatives considered: (a) the image's LLVM / package managers (choco, winget) — attempted repeatedly, deterministically truncated installs and hangs (evidence runs 13–25); (b) VS-bundled Clang/LLVM toolset — probed, ships no `llvm-config.exe` or CMake modules; (c) `INSTALLED_FAUST=ON` with a prebuilt libfaust — no official libfaust binaries for all three platforms, and it would stop testing the bundled-Faust path we ship; (d) build LLVM from source — far too slow. The old hand-rolled LLVM 9/14 zips remain rejected as EOL and dead URLs; the faust-project archive is current, maintained upstream, and checksummed.

**D4 — `CMakeLists.txt` minimum raised to 3.5 (matching what Faust's own `build/CMakeLists.txt` already declares).**
Not 3.10+, not 3.20: 3.5 is the exact floor CMake 4 still accepts, keeps the widest distro compatibility, and matches the bundled Faust. One line.

**D5 — Triggers: keep `push` (tracked branches) and `tags`, add `workflow_dispatch`. No `pull_request` trigger.**
Rationale: the user's stated workflow is a manually runnable matrix; PR builds would double cost for no consumer (public repo = free anyway, but no reason to burn runner time). Free-plan safety comes from public visibility, not from trigger minimization — noted so nobody later "optimizes" triggers thinking they are load-bearing.

**D6 — Artifact strategy: short `retention-days` (7), one artifact per platform, zipped release assets on tags.**
Free-plan artifact storage is a shared 500 MB allowance (Actions + Packages). Three platform artifacts — the macOS one being largest because it bundles Homebrew LLVM dylibs — can exceed that after a handful of runs. Retention of 7 days bounds the steady state; tags are the durable distribution channel via release assets (release storage is not the shared artifact allowance). Alternative considered: `if-no-files-found` + always-upload — rejected as it hides failures.

**D7 — Action versions: `actions/checkout@v5`, `actions/upload-artifact@v4`, `actions/download-artifact@v4`, `softprops/action-gh-release@v2`.**
Node 20 runtimes were removed from runners in Sep 2026, so anything older than the Node 24 generation is dead. Version pins are written as majors (`@v5`) to get patch updates.

**D8 — Acceptance is artifact-driven: CI is the only build, the local machine only installs.**
The Linux job's artifact is the deliverable. Local verification = install `faustgen2~` folder into Pd's external path, run `tests/` patches (`location.pd`, `recompile.pd`) plus the help patch, quit Pd.

## Risks / Trade-offs

- **Faust 2.54.9 → 2.88.0 is a two-year jump** (JIT backend, factory lifecycle, library API) and may break `src/faust_tilde_*.c` or change generated-code behavior → Mitigation: build early on Linux first; treat compile errors as the first apply task's deliverable, not a surprise. PR #5 was authored against recent Faust, which suggests the surrounding code already assumes the newer API.
- **Pure Data 0.53-1 → 0.56-x headers** may reintroduce the API churn partially addressed by `dac526c` (`sys_trytoopenone`) → Mitigation: that commit already targets 0.55.1+ headers; verify against 0.56 during the Linux build task.
- **The runner image's Windows LLVM is broken upstream** (deterministic truncated install; open issue actions/runner-images #14260) → Mitigation: the Windows job provisions LLVM from faust's pinned, checksum-verified archive instead (D3); task 4.1 still asserts `llvm-config` + `LLVMConfig.cmake` before the build, so a bad archive fails fast rather than silently.
- **Homebrew LLVM dylib bundling on macOS** (install-name rewriting) is fiddly and version-dependent → Mitigation: keep the existing `otool`/`install_name_tool` loop, only updating the prefix to `$(brew --prefix)/opt/llvm/lib`; verify with `otool -L` in the job before upload.
- **macOS artifact size vs 500 MB free storage** → Mitigation: D6 (7-day retention) and zipped release assets.
- **Artifact naming depends on `git describe`** → requires `fetch-depth: 0`, retained from the current workflow.
- **Local "no warnings" bar is environment-specific** (exact Pd version, double-precision build, external search path unknown) → see Open Questions.

## Migration Plan

1. Source base first, locally: apply PR #5, bump submodule gitlinks, raise the CMake floor, get a clean local configure/build (Linux) — this de-risks D1's version jump before any CI work.
2. Rewrite the workflow for the Linux job alone and get it green (cheapest runner, fastest iteration).
3. Add macOS arm64, then Windows, one job at a time.
4. Add `workflow_dispatch` + the tag/release job last, then trigger a full manual run as the acceptance gate.
5. Rollback = `git revert` of the workflow rewrite; the source-base changes are independent commits and can be reverted selectively. No data or migration concerns.

## Open Questions

- **Exact local environment**: which immutable distro, which Pd build/version, and whether Pd is double-precision (`PD_FLOATSIZE64`). Affects only which local acceptance patches are run, not the specs (which already say "Pd 0.55 or later") — answerable during apply without design changes.
- **The precise warnings currently observed on the local machine**: PR #5 addresses the exit crash; if additional load-time warnings exist, they may be a separate defect. To be captured as evidence during apply; if they turn out to be a distinct bug, that becomes its own change.
