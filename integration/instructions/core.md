# Core compatibility rules

## MUST

- Keep one deterministic, noninteractive startup command in `enmanner/enmanner.json`.
- Keep the server process in the foreground so Enmanner can supervise it.
- Bind the server to loopback by default and respect `ENMANNER_PORT`.
- Keep a cheap readiness URL available.
- Monitor relevant source changes and preserve framework-native hot reload.
- Make browser clients recover after a server restart.
- Keep runtime data outside generated build output.
- Keep secrets out of source, Git, logs, and `enmanner/enmanner.json`.
- Keep project dependencies inside this repository; do not install them
  system-wide.
- Treat the repository, never the generated `.app`, as editable source.
- Ensure ordinary web-source changes work without rebuilding the `.app`.

## SHOULD

- Make startup idempotent and shutdown graceful.
- Show useful user-facing errors.
- Preserve user-entered state across safe upgrades.
- Keep generated files reproducible and disposable.
- Let the coding agent create quiet Git checkpoints before risky changes and
  after working milestones. Never overwrite uncommitted user work.
- Give the app a distinctive icon. An existing app icon is not necessarily
  valid modern source artwork: reject assets with a baked container treatment.
  Reconstruct layered artwork or use image generation when needed, and follow
  the hard preflight and acceptance gates in `icon.md`.

## MAY

- Use the embedded WKWebView only after affirmatively testing its compatibility;
  the default-browser presentation is the safe default.
- Add project-specific native window dimensions.
- Extend the app with project-local tools that do not change the compatibility
  contract.
