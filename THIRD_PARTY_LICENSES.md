# Third-Party Components

This project may rely on third-party components during development and runtime.

## Runtime Binaries

- `mihomo` is redistributed in this repository at `Resources/mihomo/mihomo`.
- Bundled version:
  - Name: Mihomo Meta
  - Version: `1.19.23`
  - Build info: `darwin arm64 with go1.26.2 (2026-04-07T22:45:04Z)`
  - SHA256: `d7dfedd3120c17a7a3e80f6b7d637834ea102776c2d70a1d6e2553467a82db90`
- Upstream source: https://github.com/MetaCubeX/mihomo
- Please comply with upstream license terms when redistributing binaries in downstream releases.

## Tooling

- Development tooling under `vendor/bundle` is local-only and ignored from source control by default.

## Maintainer Checklist

Before shipping binaries with releases:
1. Verify bundled binary version and SHA256.
2. Include exact upstream version/source link.
3. Include/update upstream license text in release artifacts when required.
