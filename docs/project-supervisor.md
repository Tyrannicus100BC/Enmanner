# Project-owned supervisor

Enmanner intentionally owns one foreground command. A project with a frontend,
backend, and local infrastructure should expose one project-owned supervisor
script rather than asking the launcher to infer ownership of several services.

Copy `.enmanner/templates/project-supervisor` to `enmanner/start`, make it
executable, and adapt its executable-plus-argument arrays. Configure
`server.command` with `["./enmanner/start"]` when `server.workingDirectory` is
the project root.
The template:

- starts each required long-running service without `eval` or shell command
  strings;
- leaves every child in the process group Enmanner owns;
- forwards termination and waits for its children;
- exits when any required service exits;
- remains in the foreground for the application lifetime.

The supervisor should start only project-owned resources. Treat Docker Desktop
and already-running shared databases as prerequisites: check them, explain how
to start them, and do not silently adopt or stop them.

Database migrations should run to completion before the long-running services
start. If a service needs its own fixed port, keep the public frontend on
`${ENMANNER_PORT}` and make the configured readiness URL exercise enough of the
stack to be meaningful.

Runtime validation proves observable shutdown postconditions for the launched
process tree, selected port, and readiness URL. It cannot prove cleanup of a
container, daemon, or process that deliberately escapes project ownership.
