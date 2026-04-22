# Cusp Release Guide

This repository includes a GitHub Actions workflow at `.github/workflows/release.yml`
to build, notarize, and publish a macOS release package (`.zip` + `.dmg`).

## 1) Configure GitHub Secrets

In repository settings (`Settings -> Secrets and variables -> Actions`), add:

- `BUILD_CERTIFICATE_BASE64`: Base64 of your `Developer ID Application` `.p12` certificate
- `P12_PASSWORD`: Password for that `.p12`
- `KEYCHAIN_PASSWORD`: Temporary keychain password used in CI
- `APPLE_ID`: Apple account email
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password for notarization
- `APPLE_TEAM_ID`: Apple Developer Team ID

## 2) Trigger Release

Two ways:

1. Push a tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

2. Or run manually:
- GitHub -> `Actions` -> `Release` -> `Run workflow`
- Input tag like `v0.1.0`

## 3) Output Artifacts

Workflow output includes:

- `Cusp-vX.Y.Z.zip` (notarized app bundle zip)
- `Cusp-vX.Y.Z.dmg`
- `SHA256SUMS.txt`

The workflow also creates/updates the GitHub Release under the same tag.

## 4) Common Troubleshooting

- Signing error: verify `BUILD_CERTIFICATE_BASE64` and `P12_PASSWORD`.
- Notarization error: verify `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`.
- Tag format check: use `v<major>.<minor>.<patch>` such as `v0.1.0`.
