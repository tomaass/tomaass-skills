# tomaass-skills

A public repository. Skills here are exported from private working
repositories; only what is deliberately chosen gets published.

## Adding a skill

- One plugin per skill: `plugins/<skill>/.claude-plugin/plugin.json`,
  `plugins/<skill>/skills/<skill>/SKILL.md`, `plugins/<skill>/README.md`,
  plus an entry in `.claude-plugin/marketplace.json` and a row in `README.md`.
- Copy, never link: no links to private repositories, their ADRs or docs.
- Sanitize: no project or client names, no local paths, no real credentials —
  placeholders like `XXXX` only.
- Be honest about setup: each README states what the reader must configure
  and the skill's known limits.

## Before committing

- Enable the hook once per clone: `git config core.hooksPath .githooks`
  (runs gitleaks on staged changes; commits fail without gitleaks installed).
- Run `gitleaks git --redact` over the whole history before pushing.
- Commit messages follow Conventional Commits, in English.
