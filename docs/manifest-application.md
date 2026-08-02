# Single-application manifest

Use this guide only when the complete useful session is one human-facing web
process with no manually started application service. If the app needs another
project-owned service, startup task, worker, or observed prerequisite, use the
full [`manifest.md`](manifest.md) component-graph reference instead.

The project-owned `enmanner/enmanner.json` uses manifest version 3. The schema
path enables editor and agent validation:

```json
{
  "$schema": "../.enmanner/enmanner.schema.json",
  "version": 3,
  "name": "Household Finances",
  "identifier": "local.enmanner.household-finances",
  "application": {
    "command": [
      "npm",
      "run",
      "dev",
      "--",
      "--host",
      "127.0.0.1",
      "--port",
      "${self.endpoints.http.port}",
      "--strictPort"
    ],
    "workingDirectory": ".",
    "environment": {
      "PORT": "${self.endpoints.http.port}"
    },
    "preferredPort": 43120,
    "readiness": {
      "path": "/",
      "timeoutSeconds": 30
    }
  },
  "window": {
    "width": 1200,
    "height": 800,
    "resizable": true
  }
}
```

Keep these compatibility rules:

- `command` is an executable-plus-arguments array, never a shell string.
- `workingDirectory` is project-relative and cannot escape the project.
- The server must remain in the foreground and bind its public listener to
  `127.0.0.1`.
- Pass `${self.endpoints.http.port}` by the mechanism the framework actually
  supports: command arguments, environment, or both.
- Keep a deterministic `preferredPort` so origin-scoped browser state remains
  stable; Enmanner falls back only while that port is genuinely occupied.
- `readiness.path` must return successfully only when the page is usable.
- Put secrets and machine-local values in a Git-ignored dotenv file, not this
  manifest. See installed `instructions/security.md` when applicable.

The inline form lowers to Enmanner's normal component graph; there is no
separate lifecycle implementation. After editing, run
`./.enmanner/scripts/validate --json`, review state ownership, and then run
`./.enmanner/scripts/validate --runtime --json`.
