# software-factory

Matt Pocock's skills, T3 Code and Grok Bot, set up once per machine and once per repo.

| File | What it does |
| --- | --- |
| `machine-setup.sh` | Parks every other global skill and installs Matt's 27 skills for Claude Code, Cursor, Grok Build and Antigravity. |
| `factory-init.sh` | Puts one or more repos on the factory. Safe to re-run. |
| `foreman.md` | The description for the Grok Bot that runs the factory. |
| `templates/` | The `AGENTS.md` block and a Node CI workflow, used by `factory-init.sh`. |

Run the scripts in Git Bash on Windows, or in any shell on macOS or Linux.

## 1. Factory machine (once)

1. Run `t3 up`, then `t3 connect`. T3 then runs as a background service you can reach from your laptop and phone.
2. Sign in to each provider on that machine: Claude Code, Cursor, Grok Build and Antigravity.
3. Run `./machine-setup.sh` to see what it would change, then `./machine-setup.sh --apply`. Parked skills go to `~/.skills-parked/<timestamp>/`; move them back to undo.
4. Refresh Matt's skills weekly. On Windows, run in PowerShell:
   ```powershell
   schtasks /Create /SC WEEKLY /D MON /ST 07:00 /TN "Matt skills refresh" /TR "\"C:\Program Files\Git\bin\bash.exe\" -lc '~/Projects/software-factory/machine-setup.sh --install'"
   ```
   On Linux, use the cron line `0 7 * * 1 ~/Projects/software-factory/machine-setup.sh --install`.

## 2. Each repo (one command)

```bash
./factory-init.sh ~/Projects/app-one ~/Projects/app-two
```

For each repo, this does what `/setup-matt-pocock-skills` would do if you picked GitHub, the default labels and single-context:
- writes `docs/agents/` from Matt's latest templates;
- adds the `## Agent skills` block to `AGENTS.md`;
- creates the triage labels.

It also adds the factory's own pieces:
- the `wayfinder:*` labels;
- a `## Factory` block in `AGENTS.md`;
- a `CLAUDE.md` that imports `AGENTS.md`;
- a `ci` workflow for Node repos;
- the `factory` topic;
- a ruleset on the default branch: PRs only, no force-push, `ci` must pass;
- a T3 project for the repo.

File changes go to `chore/factory-setup` and arrive as a PR. Merge it, and the repo is on the factory.

To set up every repo you've cloned, run it on the folder. Folders that aren't GitHub repos are skipped. Watch for repos you don't want on the factory, such as your old skills repo:
```bash
./factory-init.sh ~/Projects/*/
```

To create a new repo and set it up:
```bash
gh repo create my-app --private --clone && ./factory-init.sh my-app
```

To pull Matt's newer `docs/agents` templates into every repo:
```bash
./factory-init.sh --refresh ~/Projects/*/
```

## 3. Grok Bot (once)

1. In Grok Bot, add T3's MCP server (`https://<your T3 address>/mcp`). Sign in at **Auto** level, and turn on the GitHub connector.
2. Create a Bot called Foreman. Paste the description from `foreman.md`.
3. Set Foreman's tool permissions:
   - **Blocked:** merging PRs, pushing code, deleting branches or repos.
   - **Needs approval:** closing issues.
   - **Always allow:** everything else.

## 4. Rollout, one stage per week

1. **By hand.** In T3, run grill-with-docs, to-spec, to-tickets, implement and code-review yourself on 2–3 tickets. Run `/retro` after each one.
2. **Add Review, Rework and Hand-off** to Foreman.
3. **Add Implement.** Foreman then picks up tickets on its own, at most 2 at once.
4. **Add Triage and Weekly health.**
