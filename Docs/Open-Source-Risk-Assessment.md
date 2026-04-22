# Cusp Open Source Risk Assessment

## Goal

Ensure the repository is safe, legally compliant, and contributor-friendly before public release.

## Risk Checklist

1. Secret leakage
- Scan for API keys, tokens, private keys, and real subscription links.
- Ensure logs and screenshots are sanitized.

2. Binary redistribution and licensing
- Do not commit runtime binaries unless redistribution terms are verified.
- Keep third-party licenses and attribution updated.

3. Build and test reproducibility
- `swift test` passes on a clean environment.
- Project can be built with documented commands.

4. Governance and collaboration
- README, LICENSE, SECURITY, CONTRIBUTING are present and actionable.
- Issue and PR templates exist to guide contributors.

5. Scope and legal posture
- README clearly states supported platforms and project scope.
- Avoid claims about guaranteed bypass capability or legal outcomes.

## Release Gate

Before making the repo public, run:

```bash
./Scripts/open_source_preflight.sh
swift test
```

Then verify no sensitive content appears in staged files:

```bash
git diff --cached
```
