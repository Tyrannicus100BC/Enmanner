# Enmanner Vite example

This is a normal Vite project with Enmanner's curated, framework-owned source
distribution tracked under `.enmanner/`. Its project-owned manifest and layered
icon artwork are grouped under the visible `enmanner/` sibling.

From a clean clone:

```bash
npm ci
./.enmanner/scripts/preview-icon
./.enmanner/scripts/build-app
open "Enmanner Vite Example.app"
```

The tracked layered icon is a complete example of Enmanner's visual finishing
workflow. `preview-icon` renders Default, Dark, Clear, and Tinted appearances
before the first app build.

To prove hot reload, edit the heading in `src/main.js` and save. Vite updates
the default-browser page without rebuilding the app.

The launcher opens `enmannerviteexample.localhost` so the browser identifies
the app at a glance. Vite still binds only to `127.0.0.1`; the friendly
hostname changes the browser URL, not the listener.

To prove process recovery while the native app is open, stop the supervised Vite
child process from an activity monitor or development tool. Enmanner starts the
configured foreground command again, waits for readiness, and restores the
browser endpoint. Reopen the Dock app during recovery to see native status.

To check startup and graceful shutdown without opening the UI:

```bash
./.enmanner/scripts/validate --runtime
```

Use “View Logs” in a startup or failure state to inspect captured server output,
“Copy for Coding Agent” to share a structured diagnostic, and “Reveal Project” to return to
the source.
