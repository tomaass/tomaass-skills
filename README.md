# tomaass-skills

[Claude Code](https://claude.com/claude-code) skills and hooks I use in daily work,
packaged so you can install just the one you need.

```
/plugin marketplace add tomaass/tomaass-skills
```

| Skill | What it's for | Install |
|---|---|---|
| [handoff-to-cloud](plugins/handoff-to-cloud) | Plan locally, let a cloud session execute the plan and open a PR — laptop closed. | `/plugin install handoff-to-cloud@tomaass-skills` |
| [worktree-guardrails](plugins/worktree-guardrails) | Hooks that keep agents in git worktrees and stop commits landing on main. | `/plugin install worktree-guardrails@tomaass-skills` |

Each skill says what transfers as-is and what you have to configure yourself
(credentials, routines, project paths). If something doesn't work for you,
open an issue or send a PR.

## License

MIT
