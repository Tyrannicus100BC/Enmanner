# Integration checklist

An Enmanner integration is complete only when lifecycle behavior, native
packaging, and visual presentation all pass. Work in this order so icon design
does not distract from server compatibility and no placeholder app is produced.

1. Inspect Git state, project ownership, runtime data, and existing services.
2. Run `integration/scripts/install --plan --json`.
3. Install the framework. If the result is `configurationRequired`, review
   `enmanner.json.example`, resolve every reported compatibility check, and
   promote a verified configuration to `enmanner.json`.
4. Verify the command is an argument array, stays in the foreground, honors
   `ENMANNER_PORT`, binds to loopback, and exposes a meaningful readiness URL.
5. Configure a preferred port in browser mode. Inferred manifests already have
   a deterministic choice with fallback.
6. Run static validation. After reviewing state ownership, opt into runtime
   validation and confirm readiness, shutdown, process-group cleanup, endpoint
   disappearance, port release, and workspace mutations.
7. Inspect existing brand assets. Create layered source artwork when necessary,
   package a modern `.icon`, and run `preview-icon` to inspect Default, Dark,
   Clear, and Tinted appearances.
8. Run `build-app`. Verify the compiled icon, ownership marker, code signature,
   Finder/Dock appearance, and native launch behavior.
9. Report tracked source and framework files separately from ignored build
   products. Do not call the integration complete before step 8.

For one frontend command, configure it directly. For several project-owned
processes, copy and adapt the project supervisor template. Treat Docker Desktop
and already-running shared services as prerequisites rather than adopted
children.
