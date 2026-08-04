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
    "browserHostname": "householdfinances.localhost",
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
- Set `browserHostname` to a single app-specific DNS label followed by
  `.localhost` only after completing the origin-state review below. This
  changes only the URL opened in the browser; the server still binds its
  endpoint's loopback host.
- `readiness.path` must return successfully only when the page is usable.
- Put secrets and machine-local values in a Git-ignored dotenv file, not this
  manifest. See installed `instructions/security.md` when applicable.

The inline form lowers to Enmanner's normal component graph; there is no
separate lifecycle implementation. After editing, run
`./.enmanner/scripts/validate --json`, review state ownership, and then run
`./.enmanner/scripts/validate --runtime --json`.

## Browser hostname decision

Before adding `browserHostname`, inspect application source and relevant client
libraries for direct or wrapped use of Local Storage, IndexedDB, Cache Storage,
the Origin Private File System, persistent cookies, and service workers. Also
check hard-coded origin, host allow-list, CORS, cookie-domain, authentication
callback, and WebSocket assumptions. These facilities are scoped to or can
behave differently on a new browser origin.

Make and state a project-specific judgment. Treat user-authored records,
documents, drafts, history, offline data, credentials, or other hard-to-recreate
state on the existing origin as important: omit `browserHostname` so Enmanner
continues to open the endpoint host. Small preferences and disposable UI state
such as scroll position, last selection, audio preference, filters, dismissed
notices, or reproducible caches do not block the vanity hostname. When no
important existing origin state is at risk and the application's host/origin
assumptions are compatible, choose a recognizable app-derived label such as
`luna.localhost` and configure it. Do not infer safety merely because a text
search finds no literal `localStorage`; account for abstractions and libraries.
