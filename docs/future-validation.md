# Decisions requiring future validation

- Verify Command Line Tools-only builds on clean Intel and Apple Silicon Macs,
  without a full Xcode installation, including the warned legacy-icon fallback.
- Test `preview-icon` across future Xcode and Icon Composer releases; its
  reproducible report currently covers Default, Dark, Clear, and Tinted
  appearances.
- Extend icon-source diagnostics beyond the generator's enforceable alpha and
  canvas checks to flag likely circular masks, baked edge borders, and outer
  shadows without rejecting legitimate artwork.
- Test the macOS 13 deployment target and WKWebView behavior across supported OS
  releases.
- Compare AppKit's lifecycle simplicity with SwiftUI only if the native shell
  grows materially.
- Record Gatekeeper and ad-hoc signature behavior after moving a project within
  the same Mac and after restoring it from an archive.
- Continue exercising process-tree shutdown through npm, pnpm, Yarn, Bun,
  Python, Ruby, and custom supervisors, including children that ignore
  `SIGTERM`.
- Test readiness redirects, slow responses, intermittent failures, IPv6
  loopback, and authentication-free health endpoints.
- Verify Vite and Next.js HMR and restart recovery across package managers,
  Node versions, and browsers.
- Determine whether any important framework requires a stable launcher-owned
  reverse proxy rather than direct selected-port access.
- Revisit which manifest fields are mandatory after several non-Vite adopters.
- Test duplicate app launches and decide whether a project-local lock or
  single-instance handoff is worth the complexity.
- Run the controlled single-agent, shared-checkout, worktree, and runtime-data
  trials in `continued-development-study.md` before expanding Enmanner into
  worktree orchestration or isolated test-instance management.
