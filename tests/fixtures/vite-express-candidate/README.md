# Vite + Express adapter reference

This is the smallest project shape expected to produce Enmanner's inactive
two-service component-graph draft. It intentionally contains no installable
application and is used only for installer inference tests.

The adapter requires all of these signals:

- a root Vite dependency and a root Express dependency;
- an unambiguous npm-compatible lockfile;
- `dev:web` directly invoking Vite;
- `dev:api` directly invoking a recognized root Express entry file;
- `process.env.PORT`, `process.env.HOST`, and `app.listen(PORT, HOST)` in that
  entry file; and
- a root Vite proxy configuration that reads `API_PORT`.

Run `integration/scripts/install --plan --json` against this directory and
inspect `inference.componentGraphAdapter` to compare a near miss.
