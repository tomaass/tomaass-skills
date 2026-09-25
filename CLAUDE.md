# tomaass-skills

A public repository. Skills here are exported from private working
repositories; only what is deliberately chosen gets published.

## Adding a skill

- One plugin per skill or hook set: `plugins/<name>/.claude-plugin/plugin.json`,
  `plugins/<name>/skills/<name>/SKILL.md` or `plugins/<name>/hooks/hooks.json`,
  `plugins/<name>/README.md`,
  plus an entry in `.claude-plugin/marketplace.json` and a row in `README.md`.
- Copy, never link: no links to private repositories, their ADRs or docs.
- Sanitize: no project or client names, no local paths, no real credentials —
  placeholders like `XXXX` only.
- Be honest about setup: each README states what the reader must configure
  and the skill's known limits.

- Hooks ship with a test script, wired into `.github/workflows/test.yml`.

## Before committing

- Enable the hook once per clone: `git config core.hooksPath .githooks`
  (runs gitleaks on staged changes; commits fail without gitleaks installed).
- Run `gitleaks git --redact` over the whole history before pushing.
- Commit messages follow Conventional Commits, in English.
