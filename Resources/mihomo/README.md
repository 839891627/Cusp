# `mihomo` Runtime Binary Policy

This folder is a local runtime placeholder.

## Open-source policy

- Do not commit `Resources/mihomo/mihomo` into source control.
- Acquire the binary from official upstream sources and follow upstream license terms.
- Verify integrity (checksum/signature) before use.

## Local setup

Place a prebuilt executable named `mihomo` in this folder before running the app.

Expected runtime path inside the app bundle:

`Cusp.app/Contents/Resources/mihomo`

Set executable bit:

```bash
chmod +x Resources/mihomo/mihomo
```
