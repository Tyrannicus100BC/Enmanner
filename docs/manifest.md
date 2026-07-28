# Manifest

`enmanner.json` is project-owned, versioned configuration. `.enmanner/enmanner.schema.json`
provides editor and agent validation.

```json
{
  "$schema": "./.enmanner/enmanner.schema.json",
  "version": 1,
  "name": "Household Finances",
  "identifier": "local.enmanner.household-finances",
  "server": {
    "command": [
      "npm",
      "run",
      "dev",
      "--",
      "--host",
      "127.0.0.1",
      "--port",
      "${ENMANNER_PORT}",
      "--strictPort"
    ],
    "workingDirectory": ".",
    "environment": {
      "PORT": "${ENMANNER_PORT}"
    },
    "preferredPort": 43120,
    "readiness": {
      "url": "http://127.0.0.1:${ENMANNER_PORT}/",
      "timeoutSeconds": 30
    }
  },
  "window": {
    "mode": "embedded",
    "width": 1200,
    "height": 800,
    "resizable": true
  },
  "development": {
    "reload": "auto"
  }
}
```

`version` is currently `1`. `name` becomes the `.app` display name and may not
contain slash or colon. `identifier` is a reverse-DNS bundle identifier.

`server.command` is an argument array. Enmanner executes the first item directly;
it does not invoke a shell. A first item containing a relative path, such as
`./start`, is resolved from `server.workingDirectory` and must stay inside the
project. Bare executable names use Enmanner's GUI-safe `PATH`; absolute executables
are also supported. `workingDirectory` and optional `icon` are project-relative
and may not escape through `..` or symlinks.

For current macOS icon behavior, `icon` should point to an Icon Composer
`.icon` package. Enmanner compiles it with Xcode's `actool`, adds `Assets.car` and
`CFBundleIconName`, and retains the compiled `.icns` as an older-system
fallback. A directly configured `.icns` is also accepted as legacy-only
packaging. See `.enmanner/instructions/icon.md` in an installed project for artwork
and verification requirements.

Enmanner controls two substitutions:

- `${ENMANNER_PORT}` — an allocated loopback port
- `${ENMANNER_PROJECT_DIR}` — the resolved project directory

Unknown substitutions fail validation. Do not store secrets in `environment`.

Optional `server.preferredPort` asks Enmanner to reuse a stable loopback port across
launches, preserving origin-scoped browser state such as `localStorage`. If the
preferred port is unavailable, Enmanner allocates another port and exposes the
actual choice through `${ENMANNER_PORT}`. Ports below 1024 are rejected.

`readiness.url` must use HTTP(S) on `127.0.0.1`, `localhost`, or `::1`.
Successful and redirect responses count as ready. `timeoutSeconds` is the
overall startup deadline.

Runtime validation starts and stops the configured command. For applications
with databases, containers, or other stateful services, review ownership,
mounts, backups, and controlled stop/start persistence before running it.

`window.mode` is `embedded` or `external`. Embedded mode owns a native web
window. Closing it leaves the app and server running; clicking the Dock icon
reopens it. External mode launches windowlessly, remains in the Dock, and opens
the readiness URL in the user's default browser once the server is ready. A
Dock click from another app foregrounds the launcher, while another click when
it is already active reopens the browser. Quit or Command-Q stops the server in
either mode. Startup failures still open the status window automatically.
Dimensions and resizability apply to native windows and require an app rebuild
after changes.

`development.reload` records whether automatic recovery is expected. The MVP
supports `auto` and `manual`; it always preserves framework HMR, while launcher
restart behavior is currently automatic after the first successful readiness.
