# Persistence

## MUST

- Separate editable source from runtime data and generated build output.
- Never store live databases, uploads, or user documents inside the `.app`.
- Never commit live user data unless the user explicitly chose a source-owned
  document format.
- Before runtime validation, identify stateful services and confirm their data
  ownership, mount destinations, and stop/start behavior.
- For Docker Compose, inspect the running container rather than assuming an
  image's data directory. Distinguish `stop`, `down`, and `down -v`; never use
  `down -v` in Enmanner lifecycle or validation.
- Preserve or back up existing volumes before changing lifecycle behavior, then
  verify persistence with a controlled stop/start test.

## SHOULD

- Use SQLite for structured local data when appropriate.
- Use plain files for small, document-like datasets.
- Give records stable identifiers.
- Keep database migrations in source control and make them repeatable.
- Back up data before destructive migrations.
- Provide import/export for important user-owned data.
- Keep local data in an explicit project data directory for the MVP and ignore
  it in Git.

Enmanner can present explicitly declared local settings stored in a Git-ignored
dotenv file. This is configuration, not a replacement for a clear per-project
runtime-data and backup policy.
