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
- gives children a bounded graceful-shutdown window before escalation;
- exits when any required service exits;
- identifies the service that exited and includes a bounded HTTP-wait helper;
- remains in the foreground for the application lifetime.

The supervisor should start only project-owned resources. Treat Docker Desktop
and already-running shared databases as prerequisites: check them, explain how
to start them, and do not silently adopt or stop them.

Database migrations should run to completion before the long-running services
start. If a service needs its own fixed port, keep the public frontend on
`${ENMANNER_PORT}` and make the configured readiness URL exercise enough of the
stack to be meaningful.

For a frontend/backend project, start the backend, use `wait_for_http` on its
cheap internal health endpoint, and only then start the frontend. Keep service
names beside their PIDs so failures remain attributable. For Docker-backed
projects, treat Docker Desktop and shared containers as prerequisites. If the
project deliberately creates an exclusively owned container, its copied
supervisor—not Enmanner core—must trap shutdown and stop exactly that container
without deleting volumes.

Runtime validation proves observable shutdown postconditions for the launched
process tree, selected port, and readiness URL. It cannot prove cleanup of a
container, daemon, or process that deliberately escapes project ownership.
