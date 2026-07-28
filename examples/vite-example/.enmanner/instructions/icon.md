# App icon

A Enmanner launcher SHOULD have a distinctive, project-appropriate icon. Treat the
icon as part of finishing the app, not as an optional extra.

Beautiful source artwork and correct macOS bundle packaging are separate
requirements. A transparent bitmap or standalone `.icns` is not sufficient for
a modern macOS icon: current macOS can place legacy icons inside a compatibility
plate. Prefer an Icon Composer `.icon` package compiled by Enmanner with `actool`.

## Create layered artwork

1. Inspect the repository for an existing logo or icon concept that suits the
   app.
2. If none is appropriate, use the image-generation capability available in
   your coding environment to create a polished icon based on the app's purpose
   and visual language. Do not settle for a generic placeholder or text-only
   initial.
3. Build the Icon Composer document from separate background and foreground
   layers:
   - Make the background full-bleed and unmasked.
   - Give foreground artwork real transparency and enough breathing room for
     the system to crop and compose it safely.
   - Never bake in a squircle, rounded corners, outer shadow, border, backing
     plate, or transparent corners. macOS supplies the container and material.
4. In Icon Composer, verify the Default, Dark, Clear, and Tinted appearances.
   Preserve the high-resolution source artwork and the `.icon` package in
   normal tracked project directories.

## Package the modern icon

Set the project-relative `.icon` path in `enmanner.json`, for example:

```json
"icon": "assets/AppIcon.icon",
```

Enmanner uses Xcode's `actool` to compile the package. A successful modern icon
build contains:

- `Contents/Resources/Assets.car` containing the icon image stack
- `CFBundleIconName` in `Contents/Info.plist`
- a generated `.icns` resource and `CFBundleIconFile` for older macOS fallback

Creating `.icon` packages requires Icon Composer, and compiling them requires a
current full Xcode installation with `actool`. A standalone `.icns` remains
supported as a legacy fallback when that toolchain is unavailable, but agents
must not mistake it for modern packaging.

Run `./.enmanner/scripts/validate`, rebuild with `./.enmanner/scripts/build-app`, and
inspect the compiled `.app`, not merely the source PNG or Icon Composer preview.
Use `xcrun assetutil --info` on `Contents/Resources/Assets.car` and confirm it
contains an `IconImageStack`. Use `plutil -extract CFBundleIconName raw` on
`Contents/Info.plist` and confirm it names the icon. Finally, confirm the actual
Dock/Finder icon looks correct in the relevant appearances. Do not put assets
inside the generated `.app` by hand; Enmanner creates each bundle reproducibly from
the tracked project files.
