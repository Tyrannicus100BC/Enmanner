# Manifest

`enmanner.json` is project-owned, versioned configuration. `.enmanner/enmanner.schema.json`
provides editor and agent validation.

```json
{
  "$schema": "./.enmanner/enmanner.schema.json",
  "version": 2,
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
    "mode": "browser",
    "width": 1200,
    "height": 800,
    "resizable": true
  }
}
```

`version` is currently `2`. `name` becomes the `.app` display name and may not
contain slash or colon. `identifier` is a reverse-DNS bundle identifier.

`server.command` is an argument array. Enmanner executes the first item directly;
it does not invoke a shell. A first item containing a relative path, such as
`./start`, is resolved from `server.workingDirectory` and must stay inside the
project. Bare executable names use Enmanner's GUI-safe `PATH`; absolute executables
are also supported. `workingDirectory` and optional `icon` are project-relative
and may not escape through `..` or symlinks.

`server.environment` may be omitted when no additional variables are needed; it
decodes as an empty object. Validation errors include the exact field path, and
JSON diagnostics use stable `code`, `path`, and `message` fields.

For current macOS icon behavior, `icon` must point to an Icon Composer `.icon`
package whenever Xcode's `actool` is available. Enmanner compiles it, adds
`Assets.car` and `CFBundleIconName`, verifies that the catalog contains an
`IconImageStack`, and retains the compiled `.icns` as an older-system fallback.
A directly configured `.icns` is accepted automatically only when `actool` is
unavailable; otherwise validation requires an explicit `--allow-legacy-icon`
escape hatch and warns that Tahoe can place it in a compatibility enclosure.
See `.enmanner/instructions/icon.md` in an installed project for source-artwork
and visual acceptance requirements.

Enmanner controls two substitutions:

- `${ENMANNER_PORT}` — an allocated loopback port
- `${ENMANNER_PROJECT_DIR}` — the resolved project directory

Unknown substitutions fail validation. Do not store secrets in `environment`.

Optional `server.preferredPort` asks Enmanner to reuse a stable loopback port across
launches, preserving origin-scoped browser state such as `localStorage`. If the
preferred port is unavailable, Enmanner allocates another port and exposes the
actual choice through `${ENMANNER_PORT}`. Ports below 1024 are rejected.
Installer-inferred manifests receive a deterministic preferred port by default.

`readiness.url` must use HTTP(S) on `127.0.0.1`, `localhost`, or `::1`.
Successful and redirect responses count as ready by default. `timeoutSeconds`
is the overall startup deadline. Optional `acceptableStatusCodes`,
`contentTypeContains`, and `bodyContains` fields make readiness assert something
more specific than a listening HTTP server. The deadline is capped at 300
seconds deliberately: cloning, first-time dependency installation, large seeds,
and other long initialization belong in an explicit setup step rather than
normal app startup.

In browser mode, this same URL is opened in the user's default browser after it
passes readiness. Configure a meaningful human-facing application page, not a
raw JSON or text health endpoint. Enmanner intentionally uses one URL for both
purposes in the current manifest version.

Runtime validation starts and stops the configured command. For applications
with databases, containers, or other stateful services, review ownership,
mounts, backups, and controlled stop/start persistence before running it.

`window.mode` is `browser` or `embedded`. Browser mode is the conservative
default: it launches windowlessly, remains in the Dock, and opens
the readiness URL in the user's default browser once the server is ready. A
Dock click from another app foregrounds the launcher, while another click when
it is already active reopens the browser. Quit or Command-Q stops the server in
either mode. Embedded mode owns a native WKWebView window and should be selected
only after the application passes the compatibility checklist. Startup failures
still open the status window automatically.
Dimensions and resizability apply to native windows and require an app rebuild
after changes.
