# Integration sequence

An Enmanner integration is complete only after the finished, distinctive app
has been built and verified. Use this order:

1. Confirm the project has a human-facing local web interface. Ask the user
   before wrapping a headless API, proxy, worker, daemon, CLI, or
   infrastructure service.
2. Inspect Git state, runtime data, and ownership of existing services. Do not
   run another copy concurrently when both would mutate the same local data.
3. Run the installer JSON plan and review exact file operations and unresolved
   checks.
4. Install framework files. When configuration is required, review
   `enmanner/enmanner.json.example`; never treat the draft as verified configuration.
5. Read `development-server.md`, then verify foreground execution,
   `ENMANNER_PORT`, loopback binding, readiness, shutdown, and preferred-port
   behavior. Use the project supervisor template for multiple owned processes.
6. Read `persistence.md` and `security.md` when the project has stateful
   services, containers, secrets, uploads, user data, or machine-local settings.
   When adding `userConfiguration`, curate only values a person should edit or
   verify. Use consistent human-facing Title Case independent of dotenv key
   casing, and keep descriptions useful, concise, and at most 80 characters.
7. Run static validation. Review state ownership before opting into runtime
   validation.
8. Only after lifecycle behavior passes, read `icon.md`, create layered artwork
   under `enmanner/icon/`, configure its project-relative path in
   `enmanner/enmanner.json`, render all appearances with `preview-icon`, and
   open every rendition to inspect its crop and balance.
9. Run `build-app` and inspect the actual Finder/Dock result. The build verifies
   modern icon packaging, app ownership metadata, and the code signature.
10. Report the task complete only after the finished app passes.

Ordinary web source edits do not require rebuilding the app.
