# Integration sequence

An Enmanner integration is complete only after the finished, distinctive app
has been built and verified. Use this order:

1. Inspect Git state, runtime data, and ownership of existing services.
2. Run the installer JSON plan and review exact file operations and unresolved
   checks.
3. Install framework files. When configuration is required, review
   `enmanner.json.example`; never treat the draft as verified configuration.
4. Read `development-server.md`, then verify foreground execution,
   `ENMANNER_PORT`, loopback binding, readiness, shutdown, and preferred-port
   behavior. Use the project supervisor template for multiple owned processes.
5. Read `persistence.md` and `security.md` when the project has stateful
   services, containers, secrets, uploads, or user data.
6. Run static validation. Review state ownership before opting into runtime
   validation.
7. Only after lifecycle behavior passes, read `icon.md`, create layered artwork,
   configure the `.icon` package, and render all appearances with
   `preview-icon`.
8. Run `build-app` and inspect the actual Finder/Dock result. The build verifies
   modern icon packaging, app ownership metadata, and the code signature.
9. Report the task complete only after the finished app passes.

Ordinary web source edits do not require rebuilding the app.
