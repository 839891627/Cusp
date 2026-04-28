# `mihomo` Runtime Binary Policy

This folder contains the pinned local runtime binary used by unsigned development builds.

## Open-source policy

- Acquire the binary from official upstream sources and follow upstream license terms.
- Verify integrity before use. The app validates the pinned SHA256 at launch.
- Keep `THIRD_PARTY_LICENSES.md` and `MihomoRuntimeManifest.bundled` in sync when replacing the binary.

## Current pinned binary

- Name: Mihomo Meta
- Version: `1.19.23`
- SHA256: `d7dfedd3120c17a7a3e80f6b7d637834ea102776c2d70a1d6e2553467a82db90`
- Upstream: https://github.com/MetaCubeX/mihomo
- License: GNU General Public License v3.0

## Runtime path

Expected runtime path inside the app bundle:

`Cusp.app/Contents/Resources/mihomo`

Set executable bit:

```bash
chmod +x Resources/mihomo/mihomo
```
