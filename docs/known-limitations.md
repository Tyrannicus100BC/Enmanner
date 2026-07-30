# Known limitations

- macOS 13+ only; Intel and older macOS builds have not yet been exercised.
- The launcher assumes the project's required runtime is already installed. It
  augments the sparse GUI PATH with `/opt/homebrew/bin` and `/usr/local/bin`,
  but version-manager-only runtimes may need an explicit executable path.
- The component graph starts services in deterministic topological order; it
  does not yet start independent ready branches concurrently.
- Unexpected managed-service exit restarts that service and its transitive
  dependants with stable endpoint allocations. Dependency-specific restart
  policies and continuous degraded-state monitoring remain future work.
- Prerequisite checks and service readiness are startup gates, not continuous
  health monitors.
- A successful startup task is retained for the launcher session. Task results
  are not yet invalidated by dependency generations.
- Process-group termination cannot guarantee cleanup of children that
  deliberately detach into another session.
- Free-port selection has a short close-before-launch race.
- Browser origins change between launches unless the application endpoint's
  preferred port remains available. There is no stable-origin proxy or atomic
  multi-port allocation.
- Runtime logs are bounded and memory-only.
- Project Settings supports single-line dotenv assignments. Duplicate declared
  keys, malformed quoting, and multiline values require manual cleanup rather
  than risking a destructive rewrite.
- Restart recovery is bounded and does not preserve in-memory server state.
- No code sandbox, encrypted secret store, data migration framework, backup service,
  project upgrade manager, auto-updater, notarization, or public distribution.
- Browser mode keeps a native status window but is intentionally basic.
- Installer inference completes configuration for tested root Vite and Next.js
  projects using npm, pnpm, Yarn, or Bun, plus narrowly matched direct Express
  entry points whose `PORT`, `HOST`, and `listen` flow agree. Custom scripts,
  monorepos, and other stacks receive an inactive draft, candidates, structured
  unresolved checks, and a `configurationRequired` result.
- Automated appearance previews depend on the current Xcode-bundled Icon
  Composer renderer. The actual Finder and Dock result still needs visual
  inspection on the target macOS release.
- The generated app uses local ad-hoc signing and is intended for the same Mac,
  not opaque binary sharing.
