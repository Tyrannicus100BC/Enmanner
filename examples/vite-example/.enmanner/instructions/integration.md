# Integration sequence

An Enmanner integration is complete only after the finished, distinctive app
has been built and verified. A development-only bundle can prove native
lifecycle behavior earlier, but cannot satisfy completion. Use this order:

1. Confirm the project has a human-facing local web interface. Ask the user
   before wrapping a headless API, proxy, worker, daemon, CLI, or
   infrastructure service.
2. Inspect Git state, runtime data, and ownership of existing services. Do not
   run another copy concurrently when both would mutate the same local data.
3. Run the installer JSON plan and review exact file operations and unresolved
   checks.
4. Install framework files. When configuration is required, review
   `enmanner/enmanner.json.example`; never treat the draft as verified configuration.
5. Read `development-server.md`, then verify component ownership, foreground
   execution, endpoint references, loopback binding, dependency ordering,
   readiness, shutdown, and preferred-port behavior.
6. Read `persistence.md` and `security.md` when the project has stateful
   services, containers, secrets, uploads, user data, or machine-local settings.
   When adding `userConfiguration`, curate only values a person should edit or
   verify. Use consistent human-facing Title Case independent of dotenv key
   casing. Treat descriptions as compact subtitles: add information the label
   does not, prefer 45 characters or fewer, never exceed 60, and omit one that
   would merely restate the label.
7. Run static validation. Review state ownership before opting into runtime
   validation.
8. When native launcher behavior needs verification before icon work, run
   `build-app --development` and `test-app --development`. Treat the separate
   app, bundle identifier, DEV icon, and doctor evidence as provisional.
9. Only after lifecycle behavior passes, read `icon.md`, create layered artwork
   under `enmanner/icon/`, and use `create-icon --legacy-output` on the
   Xcode-equipped Mac to generate both committed icon formats. Configure them
   as `icon.modern` and `icon.legacy` in `enmanner/enmanner.json`, render all
   appearances with `preview-icon`, and inspect every rendition on the
   generated contact sheet for crop and balance. Open an individual rendition
   when the contact sheet leaves any ambiguity.
10. Run `build-app` and inspect the actual Finder/Dock result. The build verifies
   modern icon packaging, app ownership metadata, and the code signature. Run
   `test-app` to verify native launch, readiness, normal quit, and cleanup.
11. Report the task complete only after the finished app passes. A development
    app or development test receipt is never final evidence. Report local
    technical completion separately when durable files remain untracked;
    Enmanner never stages or commits them.

Ordinary web source edits do not require rebuilding the app.
At any point, `./.enmanner/scripts/doctor --next` prints a tailored Markdown
summary of current evidence, remaining actions, and only the focused references
that apply.
