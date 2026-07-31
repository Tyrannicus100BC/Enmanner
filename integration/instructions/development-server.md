# Runtime components

## MUST

- Start from a product-level service inventory. Inspect the target's repository
  root, parent, and siblings for cooperating frontends, APIs, workers, startup
  tasks, datastores, containers, and external prerequisites before choosing
  inline `application` configuration.
- Use a component graph whenever the user-facing workflow requires more than
  one project-owned process, startup task, or observed prerequisite. Choosing a
  frontend as the application endpoint does not exclude its dependencies from
  the graph.
- Classify by intended lifecycle ownership, not repository location. Use a
  `service` when opening the app should start the process; use a `prerequisite`
  only for separately administered infrastructure that should remain running
  independently. A required HTTP API is usually a service, even when its code
  lives in a sibling repository.
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
- Give every service a readiness probe. Use `type: "process"` with a short
  `minimumUptimeSeconds` for a worker that has no meaningful network endpoint.
- When a startup task must temporarily run a server, declare its endpoints and
  a `completion` probe. Do not write a supervisor script solely to start, poll,
  and kill that process. Give expensive preparation a finite timeout and emit
  useful progress on stdout or stderr; JSON Lines validation streams it with
  the task's component label.
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
- Use longer finite probe timeouts for genuinely expensive first-run work;
  timeouts may be as long as 86400 seconds.

Enmanner allocates named endpoints, expands only documented endpoint and project
references, traverses the dependency graph, captures labelled output, and owns
each managed service's process group until the native app quits.

Runtime validation checks all launched process trees, the application endpoint,
every Enmanner-owned port, tracked descendants, non-loopback listeners, and the
Git-status delta after shutdown. Fixed prerequisite ports are observed and are
not expected to close.
