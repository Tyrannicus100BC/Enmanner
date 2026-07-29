# Enmanner compatibility

Enmanner is installed in this repository. The repository is the editable source of
truth; the generated `.app` is only a reproducible native front door.

Start with `instructions/integration.md`. It defines the required sequence and
routes to the focused rules below only when they apply.
The installer plan's `requiredInstructions` array records this routing with a
reason for each selected reference.

Every file inside `.enmanner/` is vendored, framework-owned code. Do not add
project overrides there or edit native internals during an integration. Keep
the manifest, icon package, and icon source artwork in the visible, project-owned
`enmanner/` sibling.
Spell both `enmanner/` and `.enmanner/` exactly in lowercase. Do not adapt their
casing to the repository's naming style.

Before changing application startup, networking, persistence, secrets, reload
behavior, native presentation, or collaboration, read the focused rules in
`instructions/`:

- `core.md` — required compatibility contract
- `icon.md` — app icon selection, generation, and configuration
- `development-server.md` — startup, ports, readiness, and shutdown
- `reload.md` — hot reload and restart recovery
- `persistence.md` — project source versus runtime data
- `security.md` — secrets, local networking, dependencies, and trust
- `collaboration.md` — why sharing is an architecture change

## App icon

A finished Enmanner app should have a distinctive icon. Do not leave the launcher
with a generic or missing icon merely because the repository has no ready-made
asset. A flattened legacy app icon is not valid modern source artwork merely
because it already exists. Follow the hard preflight and acceptance gates in
`instructions/icon.md`; when no appropriate layered asset is available,
reconstruct it or use your image-generation capability. When `actool` is
available, a `.icon` package is required.

Validate lifecycle behavior before beginning icon work. When necessary, use
`scripts/build-app --development` and `scripts/test-app --development` to test
the native launcher with its separate identity and conspicuous DEV icon. Do
not report the app complete until the finished icon passes its acceptance gate.
Use `scripts/preview-icon` to render Default, Dark, Clear, and Tinted appearances.

Treat **MUST** as required, **SHOULD** as the safe default, and **MAY** as
optional. Run `./.enmanner/scripts/validate --runtime` after changing runtime
behavior; use `--json` for structured diagnostics. For a multi-component
project, declare services, tasks, prerequisites, endpoints, and dependencies in
`enmanner/enmanner.json`. Rebuild the `.app` only
when native configuration or launcher files change; ordinary web source edits
do not require it.

Use `--json-lines` when an agent needs progress during runtime validation.
After the final `build-app`, run `scripts/test-app`; `doctor.complete` requires
its build-matched final native launch and cleanup evidence. Development test
evidence is reported separately and never satisfies completion.
