# Philosophy

Enmanner starts from the belief that AI should generate applications, not
development chores.

The human is the product owner and end user. The coding agent is the developer.
A person should be able to ask for a household-finance tracker without first
learning Terminal, localhost, ports, package managers, process supervision,
native bundles, code signing, or Git vocabulary.

That convenience must not come from hiding ownership:

- The repository remains inspectable and is the source of truth.
- Source is not trapped inside an opaque app bundle.
- The launcher is small, replaceable, and reproducible.
- Project dependencies stay with the project.
- Hidden system directories are used minimally.
- Deleting a local project should be as understandable as deleting its folder.
- Git provides history, checkpoints, restore, and undo without forcing the user
  to learn staging, rebasing, or branch management.
- Enmanner should make correct lifecycle, storage, reload, and security behavior the
  easiest behavior.
- Beginners should not be forced to make architectural decisions they cannot
  reasonably evaluate.

Native enough is enough. The web application is the product interface; AppKit
exists to make startup, switching, supervision, recovery, and failure feel like
a Mac application. Enmanner should not grow native complexity for its own sake.

The user owns an app. Enmanner manages the invisible development mechanics on their
behalf.
