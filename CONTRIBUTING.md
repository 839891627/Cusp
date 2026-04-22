# Contributing to Cusp

Thanks for contributing.

## Development Setup

1. Use macOS 14+ with Xcode 16+.
2. Clone repository.
3. Run:

```bash
./run.sh
```

4. Run tests:

```bash
swift test
```

## Pull Request Guidelines

- Keep PR scope focused.
- Include screenshots for UI changes.
- Include tests for parser/config/runtime behavior changes when possible.
- Keep user-facing copy concise and bilingual-ready (EN / 简体中文).

## Commit Hygiene

- Never commit secrets, subscription tokens, or private keys.
- Do not commit local build artifacts (`.build`, `.DerivedData`, `vendor/bundle`).
- Do not commit runtime binaries unless license and redistribution terms are explicitly documented.

## Before Opening a PR

Run:

```bash
./Scripts/open_source_preflight.sh
swift test
```

