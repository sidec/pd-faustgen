## Why

The Pd import libraries vendored in the `pd.build` submodule are a frozen 2023 snapshot (x64 `pd.def`: 1393 exports, missing `pdgui_vmess`), so pd-faustgen compensates on every Windows CI run by re-downloading the official Pd zip, parsing its PE exports, and invoking `lib.exe` to derive a fresh `pd.lib`. That derivation logic belongs with the library itself: the maintained fork `sidec/pd.build` should produce and carry up-to-date libs for both architectures, so every consumer (this project included) links a current library without duplicating the recipe.

## What Changes

- The `sidec/pd.build` fork gains a GitHub Action that regenerates `x64/` and `x86/` `pd.lib`+`pd.def` from sha-pinned official Pd 0.57-0 Windows binaries (`pd-0.57-0.msw.zip`, `pd-0.57-0-i386.msw.zip`) using a PE export parser and MSVC `lib.exe`, committing only when the binaries change.
- The fork README documents the recipe and the Pd-version bump ritual.
- pd-faustgen repoints the `pd.build` submodule from `pierreguillot/pd.build` to `sidec/pd.build` (**BREAKING** for consumers still pinned upstream: they must switch too or keep their own derivation) and bumps the pin to a post-regeneration commit.
- pd-faustgen's Windows CI job drops the `pd-import-library` step and the `-DPD_LIBRARY` override, linking the submodule's vendored x64 import lib directly.

## Capabilities

### New Capabilities

### Modified Capabilities

- `build-system`: the `pd.build` submodule is sourced from the maintained fork, and its vendored import libraries are regenerated per Pd release from pinned official Windows binaries (both x64 and x86) by the fork's CI — not a 2023 static snapshot.
- `ci-pipeline`: the Windows build job obtains the Pd import library from the submodule checkout; pd-faustgen CI must not download, parse, or derive import libraries itself.

## Impact

- Cross-repo: `sidec/pd.build` (new workflow + README + regenerated binaries).
- pd-faustgen: `.gitmodules` URL, submodule pin, `.github/workflows/makefile.yml` (remove `pd-import-library` step and `-DPD_LIBRARY`).
- Link failure mode shifts: a pin lagging behind `pure-data` headers now surfaces as a loud undefined-symbol link error naming the missing export.
- Removed CI dependency on `msp.ucsd.edu` from pd-faustgen; the fork's workflow carries that pinned dependency instead.
