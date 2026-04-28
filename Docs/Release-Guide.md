# Cusp Release Guide

This repository uses an unsigned release workflow intended for environments
without an Apple Developer account.

## 1) Local Unsigned Release

Build local unsigned artifacts:

```bash
./Scripts/release_unsigned_local.sh v0.1.0
```

Output directory:

- `build/dist/Cusp-unsigned-v0.1.0.zip`
- `build/dist/Cusp-unsigned-v0.1.0.dmg`
- `build/dist/SHA256SUMS.txt`
- `build/dist/UNSIGNED-NOTES.txt`

Important:
- This package is unsigned and not notarized.
- Gatekeeper may block launch until users manually allow it.
- Some system-level networking capabilities may be limited in unsigned builds.

## 2) GitHub Unsigned Release

The workflow at `.github/workflows/release.yml` calls
`./Scripts/release_unsigned_local.sh` and publishes unsigned artifacts.

Trigger methods:

1. Push a tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

2. Or run manually:
- GitHub -> `Actions` -> `Release` -> `Run workflow`
- Input tag like `v0.1.0`

## 3) Workflow Artifacts

Workflow output includes:

- `Cusp-unsigned-vX.Y.Z.zip`
- `Cusp-unsigned-vX.Y.Z.dmg`
- `SHA256SUMS.txt`
- `UNSIGNED-NOTES.txt`

The workflow also creates/updates the GitHub Release under the same tag.

## 4) Troubleshooting

- Tag format error: use `v<major>.<minor>.<patch>`, for example `v0.1.0`.
- App blocked by Gatekeeper: follow [Unsigned-Install-Guide.md](/Users/arvin/Documents/claude/FlowGate/Docs/Unsigned-Install-Guide.md).
- System proxy not restored after crash: use the app's `Restore` action on the
  overview page, or copy system proxy commands from menu and run with `sudo`.
