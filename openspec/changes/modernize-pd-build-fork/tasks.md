## 1. Fork: regeneration in sidec/pd.build

- [x] 1.1 Add `.github/workflows/regenerate.yml` to the `sidec/pd.build` fork: `windows-2025`, triggers `workflow_dispatch` + `push` (paths: the workflow file only), `permissions: contents: write`; download `pd-0.57-0.msw.zip` and `pd-0.57-0-i386.msw.zip` with pinned SHA-256 (compute and pin the i386 checksum), extract each `pd.dll`, run the stdlib-only Python PE export parser (accepts PE32 magic `0x10b` and PE32+ `0x20b`; asserts `pdgui_vmess` in x64 exports and a per-arch export-count floor), write `pd.def` (`EXPORTS`, no `LIBRARY` line), then `MSYS2_ARG_CONV_EXCL='*' lib.exe /def /machine:x64|x86 /out:...` into `x64/` and `x86/`, commit only when `x64/ x86/` differ — verify: YAML parses (`python3 -c "import yaml; yaml.safe_load(...)"`) and the workflow file exists in the fork
- [x] 1.2 Dispatch the fork workflow and verify the generated commit: `x64/pd.def` gains `pdgui_vmess`, `x64/pd.lib` and `x86/pd.lib` are non-empty, and a second dispatch produces no new commit (idempotent guard) — verify: fork run green, commit sha recorded for task 2.1
- [x] 1.3 Document the recipe and Pd-version bump ritual in the fork README (URLs, checksums, parser/lib.exe steps, keep-pure-data-pin-in-sync rule) — verify: README section exists in the fork

## 2. pd-faustgen: repoint and simplify CI

- [x] 2.1 Change `.gitmodules` `pd.build` URL to `https://github.com/sidec/pd.build.git` and bump the pin to the task 1.2 regeneration commit — verify: `git submodule status pd.build` shows the new sha and `grep pdgui_vmess pd.build/x64/pd.def` succeeds
- [x] 2.2 Remove the `pd-import-library` step and the `-DPD_LIBRARY="$PD_LIBRARY"` argument from `.github/workflows/makefile.yml` — verify: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/makefile.yml'))"` passes and `grep -c 'msp.ucsd.edu\|pd-import-library\|PD_LIBRARY' .github/workflows/makefile.yml` is 0
- [ ] 2.3 Dispatch `windows_only=true` and verify the Windows job is green without the derivation step — verify: run green, log shows no `pd-import-library` step and the link resolves against `pd.build/x64/pd.lib`

## 3. Acceptance

- [ ] 3.1 Dispatch the full workflow and verify all four jobs (Linux, macOS, Windows, tarball) are green in a single run — verify: one run with `ubuntu-build`, `macos-build`, `windows-build`, `tarball` all `success`
- [ ] 3.2 Run `openspec validate modernize-pd-build-fork` — verify: `Change 'modernize-pd-build-fork' is valid`
