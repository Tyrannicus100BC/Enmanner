# Reload and recovery

## MUST

- Keep framework-native source watching, HMR, and browser refresh enabled.
- Do not make ordinary source edits require a launcher rebuild.
- Ensure a full browser reload is safe after a server restart.

Enmanner deliberately does not replace Vite or another framework's HMR channel.
While a server is healthy, the framework owns fine-grained updates. If a
previously-ready server exits, Enmanner shows a reconnecting state, restarts the
configured command with bounded backoff, waits for readiness, and loads the app
again.

## SHOULD

- Preserve durable user data while development processes restart.
- Avoid watcher configurations that include generated `.app`, `.enmanner/.build`,
  database, upload, or cache directories.
