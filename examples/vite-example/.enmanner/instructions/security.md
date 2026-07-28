# Security and trust

## MUST

- Treat project configuration and project code as untrusted input.
- Bind local servers to loopback and do not expose them publicly.
- Never use `sudo`, change shell startup files, or install global dependencies.
- Never commit API keys, passwords, tokens, private keys, `.env`, or similar
  secret files.
- Never print secret values in launcher or server logs.
- Keep configured paths inside the project.

Enmanner runs the project's configured command with the current user's permissions.
It is not a security sandbox and agents must not describe it as one.

## SHOULD

- Prefer macOS Keychain for future managed credentials.
- Treat `.env` as a compatibility fallback and keep it ignored by Git.
- Minimize third-party launcher dependencies; the MVP uses Apple frameworks and
  Swift only.
