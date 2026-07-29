# Enmanner agent router

Choose the route that matches the task:

- Integrating Enmanner into another project: start with
  `docs/integration-checklist.md`, then use `docs/manifest.md` and the installed
  `.enmanner/AGENTS.md` as directed by that checklist.
- Modifying Enmanner itself: follow the contributor guidance below and read
  `docs/architecture.md` before changing lifecycle behavior.

Do not treat framework-development instructions as a reason to edit files inside
an installed project's `.enmanner/` directory.

## Contributor guidance

Enmanner turns project-local web applications into lightweight macOS applications.
Preserve these invariants:

- The project repository is the editable source of truth.
- Installed framework files are ordinary tracked files under `.enmanner/`.
- Generated `.app` bundles stay small and reproducible.
- Services bind declared endpoints to loopback, run in the foreground, and
  respect their allocated endpoint values.
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
