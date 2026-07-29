# Integration checklist

An Enmanner integration is complete only when project fit, lifecycle behavior,
native packaging, and visual presentation all pass. Work in this order so icon
design does not distract from server compatibility and no placeholder app is
produced.

1. Confirm the project has a human-facing local web interface. Stop and ask the
   user before wrapping a headless API, proxy, worker, daemon, CLI, or
   infrastructure service.
2. Inspect Git state, project ownership, runtime data, and existing services.
   For stateful projects, confirm that another terminal-started copy is not
   already using the same data.
3. Run `integration/scripts/install --plan --json`.
4. Install the framework. If the result is `configurationRequired`, review
   `enmanner/enmanner.json.example`, resolve every reported compatibility check, and
   promote a verified configuration to `enmanner/enmanner.json`.
5. Verify the command is an argument array, stays in the foreground, honors
   `ENMANNER_PORT`, and binds to loopback. In browser mode the readiness URL is
   also opened for the user, so it must be a meaningful human-facing page
   rather than a raw health response.
6. Configure a preferred port in browser mode. Inferred manifests already have
   a deterministic choice with fallback.
7. If people must configure machine-local values, add `userConfiguration`.
   Expose only values they should edit or verify, choose the correct control
   type, and mark only genuinely startup-blocking values as required. Use
   consistent human-facing Title Case regardless of dotenv key casing, preserve
   canonical brands and acronyms, and keep optional descriptions to one useful
   sentence of at most 80 characters.
8. Run static validation. After reviewing state ownership, opt into runtime
   validation and confirm readiness, shutdown, process-group cleanup, endpoint
   disappearance, port release, and workspace mutations.
9. Inspect existing brand assets. Create layered source artwork under
   `enmanner/icon/` when necessary, package a modern `.icon` there, add its
   project-relative path to `enmanner/enmanner.json`, then run `preview-icon`.
   Open every Default, Dark, Clear, and Tinted rendition and confirm that the
   artwork is balanced and uncropped.
10. Run `build-app`. Verify the compiled icon, ownership marker, code signature,
   Finder/Dock appearance, and native launch behavior.
11. Report tracked source and framework files separately from ignored build
   products. Do not call the integration complete before step 10.

For one frontend command, configure it directly. For several project-owned
processes, copy and adapt the project supervisor template. Treat Docker Desktop
and already-running shared services as prerequisites rather than adopted
children.
