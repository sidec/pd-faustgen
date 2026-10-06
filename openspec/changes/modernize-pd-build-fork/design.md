## Context

`pd.build` (pierreguillot, pinned 149e08a from 2023) vendors `x64/` and `x86/` `pd.lib`+`pd.def` that its `pd.cmake` links by default (`find_library(PD_LIBRARY NAMES pd HINTS ${PD_LIB_PATH})`). Those files are a 2023 snapshot: x64 `pd.def` has 1393 exports and lacks `pdgui_vmess`, which `src/faustgen_tilde.c` calls. pd-faustgen currently works around this with a CI step (added in `modernize-ci-and-refresh-base`, green in run 37477246129) that downloads `pd-0.57-0.msw.zip`, parses the PE export table with a stdlib-only Python script, and invokes MSVC `lib.exe /def` to derive a fresh x64 `pd.lib`. The user maintains a content-identical fork, `sidec/pd.build`, intended to become the maintained source of these libraries. Official Pd 0.57-0 Windows binaries exist for both arches: `pd-0.57-0.msw.zip` (x64) and `pd-0.57-0-i386.msw.zip`.

## Goals / Non-Goals

**Goals:**

- Regenerated `x64/` and `x86/` import libraries live and stay fresh in `sidec/pd.build`, refreshed by that fork's CI from sha-pinned official binaries.
- pd-faustgen links the submodule's vendored x64 lib directly; its CI carries no derivation logic.
- The regeneration recipe is executable, asserted, and documented (bump ritual for future Pd versions).

**Non-Goals:**

- Building `pd.dll` from the pure-data sources (autotools/MinGW cross-build; rejected — see Decisions).
- Forking or patching `pd.cmake`'s link logic (the existing `HINTS` default already selects `x64/`).
- Refreshing the libraries on a schedule or on upstream Pd releases automatically (manual dispatch/push only).
- Windows 32-bit builds of pd-faustgen (x86 libs refreshed for other pd.build consumers only).

## Decisions

1. **Derive libraries from official binaries; do not build `pd.dll` from source.** The PE-parser + `lib.exe` recipe is already proven in pd-faustgen CI. Building Pd from the submodule requires msys2/mingw provisioning plus Miller's `msw/build-msw-64.sh` autotools path (documented as untested outside his machine); the MSVC script is explicitly "reference only". The official zips are sha-pinned, so a tampered or changed binary fails the checksum loudly.

2. **One workflow, both arches, PE32-aware parser.** The x64 dll is PE32+ (magic `0x20b`); the i386 dll is PE32 (`0x10b`). The parser asserts magic ∈ {`0x10b`, `0x20b`}, requires `pdgui_vmess` in the x64 export set and a per-arch export-count floor, and writes `pd.def` as `EXPORTS` + names with no `LIBRARY` line (import name stays `pd`, matching `pd.build`'s convention). `lib.exe` runs with `MSYS2_ARG_CONV_EXCL='*'` and `/machine:x64` / `/machine:x86` respectively.

3. **Fork CI commits only when binaries differ.** Trigger: `workflow_dispatch` plus `push` paths-filtered to the workflow file and recipe (never the binaries themselves — avoids commit loops). A `git diff --quiet` guard on `x64/ x86/` skips the commit when regeneration is idempotent. `permissions: contents: write`.

4. **Ordering: fork first, then pd-faustgen.** The fork workflow must run and commit before pd-faustgen's pin can move to that commit; `.gitmodules` URL change and pin bump land together in pd-faustgen. The `pd-import-library` step and `-DPD_LIBRARY="$PD_LIBRARY"` are removed in the same change, so `pd.cmake`'s default `HINTS pd.build/x64` takes over.

5. **Keep the derivation recipe in git history as rollback.** Reverting the workflow edit restores the previous working state; no other rollback machinery needed.

## Risks / Trade-offs

- [Pin drift: `pure-data` bumps ahead of the fork's libs] → Link fails loudly with an unresolved external symbol naming the export; the fix is to re-run the fork workflow with the new version's pinned zips (documented bump ritual).
- [msp.ucsd.edu availability now gates the fork's CI only, not pd-faustgen's] → pd-faustgen builds are unaffected; regeneration can be re-run when the host is reachable.
- [Fork CI `contents: write` push from workflow] → scoped to the fork repo only; commit-if-changed guard prevents loops; binaries are regenerable from pinned inputs if anything goes wrong.
- [i386 zip layout assumed to mirror the x64 zip (`pd-0.57-0/bin/pd.dll`)] → the workflow asserts the path exists before parsing; a layout change fails immediately rather than writing a wrong lib.
- [Contributors with a stale local submodule checkout see the old broken lib] → normal `git submodule update --remote`/pin-follow fixes it; error surface is the same loud link failure.

## Migration Plan

1. Add the regeneration workflow + README recipe to `sidec/pd.build`; dispatch it; verify the resulting commit updates both arch libs.
2. In pd-faustgen: change `.gitmodules` URL, bump the `pd.build` pin to that commit, remove the `pd-import-library` step and `-DPD_LIBRARY` argument, validate YAML.
3. Dispatch `windows_only=true`, then a full four-job dispatch; both must be green.
4. Rollback at any point: `git revert` of the pd-faustgen commit restores the derivation step; the fork commit can be left in place harmlessly.

## Open Questions

None — the regeneration mechanism (fork CI auto-refresh) and the pd-faustgen consequence (drop derivation step) were decided with the user before this design was written.
