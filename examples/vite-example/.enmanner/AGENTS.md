# Enmanner compatibility

Enmanner is installed in this repository. The repository is the editable source of
truth; the generated `.app` is only a reproducible native front door.

Before changing application startup, networking, persistence, secrets, reload
behavior, or collaboration, read the focused rules in `instructions/`:

- `core.md` — required compatibility contract
- `development-server.md` — startup, ports, readiness, and shutdown
- `reload.md` — hot reload and restart recovery
- `persistence.md` — project source versus runtime data
- `security.md` — secrets, local networking, dependencies, and trust
- `collaboration.md` — why sharing is an architecture change

Treat **MUST** as required, **SHOULD** as the safe default, and **MAY** as
optional. Run `./.enmanner/scripts/validate --runtime` after changing server
behavior. Rebuild the `.app` only when native configuration or launcher files
change; ordinary web source edits do not require it.
