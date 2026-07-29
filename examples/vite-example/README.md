# Enmanner Vite example

This is a normal Vite project with Enmanner's curated, framework-owned source
distribution tracked under `.enmanner/`.

From a clean clone:

```bash
npm ci
./.enmanner/scripts/build-app
open "Enmanner Vite Example.app"
```

To prove hot reload, edit the heading in `src/main.js` and save. Vite updates
the default-browser page without rebuilding the app.

To prove process recovery while the native app is open, stop the supervised Vite
child process from an activity monitor or development tool. Enmanner starts the
configured foreground command again, waits for readiness, and restores the
browser endpoint. Reopen the Dock app during recovery to see native status.

To check startup and graceful shutdown without opening the UI:

```bash
./.enmanner/scripts/validate --runtime
```

Use “View Logs” in a startup or failure state to inspect captured server output,
“Copy Logs” to share it with a coding agent, and “Reveal Project” to return to
the source.
