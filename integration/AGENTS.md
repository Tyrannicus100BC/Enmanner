# Enmanner compatibility

Enmanner is installed in this repository. The repository is the editable source of
truth; the generated `.app` is only a reproducible native front door.

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
asset. Follow `instructions/icon.md`; when no appropriate existing asset is
available, use your image-generation capability to create one.

Treat **MUST** as required, **SHOULD** as the safe default, and **MAY** as
optional. Run `./.enmanner/scripts/validate --runtime` after changing server
behavior. Rebuild the `.app` only when native configuration or launcher files
change; ordinary web source edits do not require it.
