# Runtime components

## MUST

- Put each executable and argument in a JSON command array. Do not rely on shell
  parsing.
- Treat requested startup commands as intent. Verify every executable,
  argument, working directory, and build target against current project source.
- Keep every component working directory and relative executable inside the
  project.
- Use `${self.endpoints.<name>.port}` when a service must bind an allocated
  endpoint.
- Listen on `127.0.0.1` or another loopback address, never all interfaces by
  default.
- Keep managed services in the foreground. Do not daemonize, launch through
  Terminal, or leave unsupervised descendants.
- Declare `dependsOn` for startup ordering and for every cross-component
  endpoint reference.
- Use `service` for long-running owned processes, `task` for one-shot startup
  commands, and `prerequisite` for infrastructure Enmanner observes but does
  not own.
- Return a successful HTTP readiness response only when the component can
  provide the capability its dependents need.
- Treat `bodyContains` as a raw HTTP-response assertion; do not use text that
  exists only after client-side JavaScript renders.

## SHOULD

- Use commands already present in the project's dependency system. Do not
  unwrap package-manager commands in ways that skip lifecycle hooks.
- Give the application endpoint a preferred port in browser mode so
  origin-scoped state stays stable when possible.
- Before starting a stateful application, confirm that a separately
  terminal-started copy is not already using the same project data.
- Exit cleanly after `SIGTERM` and close database and file handles.
- Make repeated start and stop cycles safe.
- Add readiness whenever another component depends on more than successful
  process creation.

Enmanner allocates named endpoints, expands only documented endpoint and project
references, traverses the dependency graph, captures labelled output, and owns
each managed service's process group until the native app quits.

Runtime validation checks all launched process trees, the application endpoint,
every selected port, tracked descendants, non-loopback listeners, and the
Git-status delta after shutdown.
