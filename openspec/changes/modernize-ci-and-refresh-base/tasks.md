# Tasks: modernize-ci-and-refresh-base

## 1. Refresh the source base (local, before any CI work)

- [x] 1.1 Initialize submodules and confirm the working tree is clean (`git submodule update --init --recursive` succeeds; `git status` shows only intended changes) — verify: submodule dirs populated for `faust`, `pure-data`, `pd.build`
- [x] 1.2 Bump the `faust` gitlink to release tag 2.88.0 (`8c00913`) and `pure-data` to its current master head; leave `pd.build` at `149e08a` — verify: `git submodule status` shows exactly those SHAs and `grep "set (VERSION" faust/build/CMakeLists.txt` reports `2.88.0`
- [x] 1.3 Apply upstream PR #5 (`agraef/pd-faustgen` #5) to `src/faustgen_tilde.c`: register `atexit(deleteAllCDSPFactories)` once, guarded by a static flag, after the JIT factory/instance are stored — verify: `grep -n "atexit(deleteAllCDSPFactories)" src/faustgen_tilde.c` shows the call inside `faustgen_tilde_compile`
- [x] 1.4 Raise `cmake_minimum_required` in `CMakeLists.txt` from `2.8` to `3.5` — verify: `cmake -S . -B build` completes without a compatibility error under CMake 4.x
- [x] 1.5 Produce a clean local Linux build with bundled Faust and distro LLVM (`cmake .. -DLLVM_DIR=... && cmake --build . && cmake --install . --prefix dist`) — verify: build exits 0 and `dist/faustgen2~` contains the external, `README.md`, `LICENSE`, and a read-only `default.dsp`
- [x] 1.6 If the Faust 2.54→2.88 or Pd 0.53→0.56 jump breaks `src/faust_tilde_*.c`, fix the compile errors in the same commits — verify: step 1.5 still exits 0

## 2. Rewrite the workflow: skeleton + Linux job

- [x] 2.1 Replace `.github/workflows/makefile.yml` triggers with `push` (tracked branches), `tags: ['*']`, and `workflow_dispatch`; drop `pull_request` — verify: the YAML parses (`python3 -c "import yaml; yaml.safe_load(open(...))"` or `actionlint`)
- [x] 2.2 Write the Linux job: `ubuntu-24.04`, `actions/checkout@v5` with `submodules: recursive` and `fetch-depth: 0`, install distro LLVM dev packages, configure with `-DLLVM_DIR` from `llvm-config`, build, staged install — verify: a push-triggered run turns the job green
- [x] 2.3 Add artifact upload with `actions/upload-artifact@v4`, name `pd-faustgen2-${{ env.version }}-ubuntu-x86_64`, explicit `retention-days: 7` — verify: the artifact appears on the run and its zip contains `faustgen2~/faustgen2~.pd_linux`, README, LICENSE, read-only `default.dsp`

## 3. macOS arm64 job

- [x] 3.1 Add the macOS job on `macos-15`: `brew install llvm`, configure with `LLVM_DIR=$(brew --prefix)/opt/llvm/lib/cmake/llvm`, build, staged install — verify: job green on a push-triggered run
- [x] 3.2 Bundle Homebrew LLVM dylibs into `faustgen2~` and rewrite their install names to `@loader_path`, reusing the existing `otool`/`install_name_tool` loop with the new prefix — verify: the job's `otool -L` output shows no `$(brew --prefix)` references for non-system dylibs, and `lipo -archs` reports `arm64`
- [x] 3.3 Upload as `pd-faustgen2-<version>-macos-arm64` with `retention-days: 7` — verify: artifact present and named per spec

## 4. Windows x64 job

- [ ] 4.1 Add the Windows job on `windows-2025` with `shell: bash`: provision LLVM the way `grame-cncm/faust`'s `libfaust.yml` Windows job does — download the pinned `llvm-17.0.6-win11-x86_64.zip` from grame-cncm/faust release assets, verify its SHA-256, `7z` extract, put `llvm-config` on `PATH` — then assert LLVM usability (`llvm-config --version` runs and an `LLVMConfig.cmake` exists) — verify: the assertion step passes on a real run
- [ ] 4.2 Configure with a Visual Studio generator available on the image (VS 17+ x64) plus `-DLLVM_DIR`, build Release, staged install — verify: job green and `faustgen2~.dll` produced
- [ ] 4.3 Upload as `pd-faustgen2-<version>-windows-x86_64` with `retention-days: 7` — verify: artifact present and named per spec

## 5. Source tarball + tag release

- [x] 5.1 Update the tarball job to `checkout@v5` + `upload-artifact@v4`, keeping `./make-dist.sh` — verify: artifact `pd-faustgen2-<version>-source` appears with the `.tar.gz` inside
- [ ] 5.2 Update the release job (`if: startsWith(github.ref, 'refs/tags/')`, `needs:` all four build jobs) to `download-artifact@v4` and `softprops/action-gh-release@v2` with `draft: true`, `prerelease: true`, zipping every artifact — verify: pushing a test tag produces a draft prerelease whose assets are one zip per platform plus the source tarball

## 6. Acceptance: full matrix + local immutable Linux

- [ ] 6.1 Trigger the workflow manually via `workflow_dispatch` — verify: all four jobs (Linux, macOS, Windows, tarball) are green in a single run
- [x] 6.2 Download `pd-faustgen2-<version>-ubuntu-x86_64`, place its `faustgen2~` folder on the Pd external search path of the local immutable Linux machine — evidence: run 37444217542 ubuntu artifact on Bluefin 44 / Pd 0.57.0 (float32, x86_64): help patch opens, 18 objects resolved, exit 0, zero console warnings; ldd shows no LLVM/xml2/z3 deps — verify: `faustgen2~-help.pd` opens with every object resolved and **zero warnings on the Pd console**; record the distro, Pd version, and precision (float/double) as evidence
- [x] 6.3 Run `tests/location.pd` and `tests/recompile.pd` — evidence: CI artifact, JACK2/2ch, faustgen2~ location(0/1) and recompile(1/2) JIT-compiled, mid-run dsp edit triggered the 2nd compile, exit 0 — verify: the dsp compiles through the JIT, audio is produced, and an in-session recompile succeeds
- [x] 6.4 Quit Pd after compiling at least one dsp — evidence: both CI-artifact runs exited 0 after JIT compiles; coredumpctl shows no pd core (only an unrelated 2026-10-02 gnome-shell) — verify: Pd exits with status 0, no crash report, no static-destruction fault (the PR #5 behavior)
- [x] 6.5 If load-time warnings appear that are unrelated to PR #5's exit fix, stop and capture the exact console output for a separate change — evidence: normal-mode console has zero warnings; -verbose surfaces 12 class-overwrite notices from the flatpak Pd's own zexy/cyclone bundle (lines 37-91 of ~/faustgen-acceptance/63-tests.log), unrelated to the external and to PR #5; environment noise, kept out of this change — verify: evidence recorded in the change notes rather than absorbed silently
