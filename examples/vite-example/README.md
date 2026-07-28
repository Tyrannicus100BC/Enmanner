# Enmanner Vite example

This is a normal Vite project with Enmanner installed as tracked source under
`.enmanner/`.

From a clean clone:

```bash
npm ci
./.enmanner/scripts/build-app
open "Enmanner Vite Example.app"
```

To prove hot reload, edit the heading in `src/main.js` and save. Vite updates
the page inside the native window without rebuilding the app.

To prove process recovery while the native app is open, stop the supervised Vite
child process from an activity monitor or development tool. Enmanner changes to a
reconnecting state, starts the configured foreground command again, waits for
readiness, and reloads the page.

To check startup and graceful shutdown without opening the UI:

```bash
./.enmanner/scripts/validate --runtime
```

Use “View Logs” in a startup or failure state to inspect captured server output,
“Copy Logs” to share it with a coding agent, and “Reveal Project” to return to
the source.
