# Decisions requiring future validation

- Verify Command Line Tools-only builds on clean Intel and Apple Silicon Macs,
  without a full Xcode installation.
- Test the macOS 13 deployment target and WKWebView behavior across supported OS
  releases.
- Compare AppKit's lifecycle simplicity with SwiftUI only if the native shell
  grows materially.
- Record Gatekeeper and ad-hoc signature behavior after moving a project within
  the same Mac and after restoring it from an archive.
- Exercise process-tree shutdown through npm, pnpm, Bun, Python, Ruby, and custom
  supervisors, including children that ignore `SIGTERM`.
- Test readiness redirects, slow responses, intermittent failures, IPv6
  loopback, and authentication-free health endpoints.
- Verify Vite HMR and restart recovery across Node versions and browsers.
- Determine whether any important framework requires a stable launcher-owned
  reverse proxy rather than direct selected-port access.
- Revisit which manifest fields are mandatory after several non-Vite adopters.
- Test duplicate app launches and decide whether a project-local lock or
  single-instance handoff is worth the complexity.
