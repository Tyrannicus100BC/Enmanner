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

- Keep `.env` ignored by Git. When `userConfiguration` is present, expose only
  the values a person should configure and mark credentials as `secret` so the
  native UI masks them.
- Treat a `secret` field as presentation protection, not encrypted storage. The
  value remains in the configured dotenv file for existing project commands and
  tests.
- Consider a future optional Keychain-backed mode only when a project explicitly
  needs a different storage contract.
- Minimize third-party launcher dependencies; the MVP uses Apple frameworks and
  Swift only.
