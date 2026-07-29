# Known limitations

- macOS 13+ only; Intel and older macOS builds have not yet been exercised.
- The launcher assumes the project's required runtime is already installed. It
  augments the sparse GUI PATH with `/opt/homebrew/bin` and `/usr/local/bin`,
  but version-manager-only runtimes may need an explicit executable path.
- One launcher owns one server command. Multi-service projects use the published
  project-owned foreground supervisor template.
- Enmanner cannot infer ownership of stateful infrastructure managed by a custom
  supervisor. Runtime validation must be reviewed before use.
- Process-group termination cannot guarantee cleanup of children that
  deliberately detach into another session.
- Free-port selection has a short close-before-launch race.
- Browser origins change between launches unless `server.preferredPort` remains
  available. There is no stable-origin proxy or atomic multi-port allocation.
- Runtime logs are bounded and memory-only.
- Restart recovery is bounded and does not preserve in-memory server state.
- No code sandbox, secret store, data migration framework, backup service,
  project upgrade manager, auto-updater, notarization, or public distribution.
- External-browser mode keeps a native status window but is intentionally basic.
- Installer inference intentionally completes configuration only for tested,
  high-confidence adapters. Other stacks receive candidates and a
  `configurationRequired` result.
- The generated app uses local ad-hoc signing and is intended for the same Mac,
  not opaque binary sharing.
