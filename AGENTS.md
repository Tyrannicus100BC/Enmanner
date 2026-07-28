# Enmanner contributor guidance

Enmanner turns project-local web applications into lightweight macOS applications.
Preserve these invariants:

- The project repository is the editable source of truth.
- Installed framework files are ordinary tracked files under `.enmanner/`.
- Generated `.app` bundles stay small and reproducible.
- Servers bind to loopback, run in the foreground, and respect `ENMANNER_PORT`.
- Commands are executable-plus-argument arrays, never shell command strings.
- Configured paths stay inside the project.
- The launcher owns the child process group and stops it on quit.
- Ordinary source edits do not require a launcher rebuild.
- No global packages, `sudo`, shell-profile edits, nested Git repositories, or
  large hidden workspace.

Before changing lifecycle behavior, read `docs/architecture.md`. Keep scripts
strict, quote paths, and test spaces in project names. Run the Swift tests and
the Vite smoke test after meaningful changes. Do not commit `.build`,
`node_modules`, `.app`, live data, `.env`, or logs.
