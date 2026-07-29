# Development server

## MUST

- Put the executable and every argument in `server.command` as separate JSON
  array entries. Do not rely on shell parsing.
- Treat requested startup commands as intent. Verify every executable, argument,
  working directory, and build target against the current project source before
  writing `enmanner.json`.
- Keep `server.workingDirectory` project-relative.
- Resolve relative executable paths such as `./start` from
  `server.workingDirectory`; keep them inside the project.
- Accept the port supplied in `ENMANNER_PORT`.
- Listen on `127.0.0.1` or another loopback address, never all interfaces by
  default.
- Remain in the foreground. Do not daemonize, launch through Terminal, or leave
  an unsupervised child process behind.
- Return a successful HTTP status from the readiness URL only when the app can
  serve its interface.
- In a multi-component project, expose one project-owned foreground supervisor.
  Start and stop only project-owned resources; treat shared or already-running
  services as prerequisites that Enmanner observes but does not adopt.

## SHOULD

- Use a startup command already present in the project's normal dependency
  system, such as an npm script. Package-manager commands such as
  `npm run start` are valid foreground commands; do not unwrap them into their
  apparent underlying command because that can skip lifecycle hooks,
  environment setup, and package-manager semantics.
- Configure `server.preferredPort` in browser mode so origin-scoped state stays
  stable when possible. Installer-inferred manifests do this automatically.
  Continue to use `${ENMANNER_PORT}` because Enmanner falls back if that port is busy.
- Before starting a stateful application, confirm that a separately
  terminal-started copy is not already using the same project data. Launch
  Services prevents a second copy of the generated `.app`, but cannot identify
  every independently started project server.
- Exit cleanly after `SIGTERM` and close database/file handles.
- Make repeated start/stop cycles safe.

Enmanner allocates a free port, expands only its documented variables, starts the
command directly, captures both output streams, waits for readiness, and owns
the process group until the native app quits.

Use `.enmanner/templates/project-supervisor` as the starting point for a
multi-component project. Runtime validation checks the process group, readiness
URL, selected port, tracked descendants, and Git-status delta after shutdown.
