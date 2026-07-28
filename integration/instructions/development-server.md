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
- In a project-level multi-process supervisor, track which services were already
  running and stop only services the supervisor actually started.

## SHOULD

- Use a startup command already present in the project's normal dependency
  system, such as an npm script.
- Configure `server.preferredPort` when browser-origin persistence matters.
  Continue to use `${ENMANNER_PORT}` because Enmanner falls back if that port is busy.
- Exit cleanly after `SIGTERM` and close database/file handles.
- Make repeated start/stop cycles safe.

Enmanner allocates a free port, expands only its documented variables, starts the
command directly, captures both output streams, waits for readiness, and owns
the process group until the native app quits.
