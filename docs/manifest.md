# Manifest

`enmanner/enmanner.json` is project-owned, versioned configuration.
`.enmanner/enmanner.schema.json` provides editor and agent validation.
The containing directory is always spelled exactly `enmanner/`; repository
styling conventions do not change this machine-facing path.

```json
{
  "$schema": "../.enmanner/enmanner.schema.json",
  "version": 2,
  "name": "Household Finances",
  "identifier": "local.enmanner.household-finances",
  "userConfiguration": {
    "file": ".env",
    "template": ".env.example",
    "fields": [
      {
        "key": "IMPORT_DIRECTORY",
        "label": "Import Directory",
        "type": "directory",
        "required": true
      },
      {
        "key": "TEAM_API_KEY",
        "label": "Team API Key",
        "type": "secret"
      }
    ]
  },
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
`./enmanner/start`, is resolved from `server.workingDirectory` and must stay
inside the project. Bare executable names use Enmanner's GUI-safe `PATH`;
absolute executables are also supported. `workingDirectory` and optional `icon`
remain relative to the project root—not the manifest directory—and may not
escape through `..` or symlinks.

`server.environment` may be omitted when no additional variables are needed; it
decodes as an empty object. Validation errors include the exact field path, and
JSON diagnostics use stable `code`, `path`, and `message` fields.

Optional `userConfiguration` exposes an explicit, curated set of dotenv values
in the native Settings window. `file` defaults to `.env` and must be a
project-relative, project-owned file outside `.enmanner/`. An optional
`template`, commonly `.env.example`, supplies initial content when the
destination does not exist. The launcher materializes that template before
starting the server; installation does not create machine-local configuration.
Without a template, an explicitly configured missing destination is created as
an empty owner-only file. Enmanner never infers fields from the template.

Each field has an environment-variable `key`, human-readable `label`, optional
`description`, optional `required` flag, and one of these types. Labels should
use consistent human-facing Title Case independent of dotenv spelling, while
preserving canonical brands and acronyms. Descriptions should add information,
use one sentence of at most 80 characters, and are displayed within a strict
two-line limit.

- `string` — ordinary text, and the default when `type` is omitted
- `secret` — masked text that is still stored in the configured dotenv file
- `boolean` — a checkbox stored as `true` or `false`
- `file` — text with a native file picker
- `directory` — text with a native directory picker

Saving writes only declared keys, preserves comments, ordering, and undeclared
entries, then restarts the supervised server so normal dotenv loaders see the
new values. If required fields are blank at launch, Enmanner opens Project
Settings and waits to start the server. Secret controls are masked by default
and include an explicit reveal button for quick verification. New dotenv files
use owner-only permissions. A configured dotenv
file may not be tracked by Git. Duplicate declared keys, malformed quoting,
multiline values, and tracked destinations fail instead of risking a destructive
rewrite. `secret` controls only native presentation: values are never placed in
`enmanner/enmanner.json`, logs, diagnostics, or the `.app`, but remain ordinary dotenv
values for project commands and tests.

The `icon` path must stay inside the project-owned `enmanner/` directory. For
current macOS icon behavior, it must point to an Icon Composer `.icon` package
whenever Xcode's `actool` is available. Enmanner compiles it, adds
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

Enmanner edits the dotenv file but does not itself parse that file into the
server environment. The project command remains responsible for its established
dotenv-loading behavior.

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
