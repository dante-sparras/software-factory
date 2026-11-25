# software-factory

Matt Pocock's skills, T3 Code and Grok Bot, set up once per machine and once per repo.

| File | What it does |
| --- | --- |
| `machine-setup.sh` | Parks every other global skill and installs Matt's 27 skills for Claude Code, Cursor, Grok Build and Antigravity. |
| `factory-init.sh` | Puts one or more repos on the factory. Safe to re-run. |
| `foreman.md` | The description for the Grok Bot that runs the factory. |
| `templates/` | The `AGENTS.md` block and a Node CI workflow, used by `factory-init.sh`. |

Run the scripts in Git Bash on Windows, or in any shell on macOS or Linux.

## The design

The factory uses the language of Matt Pocock's [software-factory skill](https://github.com/mattpocock/skills/tree/main/skills/in-progress/software-factory). A **task** is a kind of work, defined once in `foreman.md`. A **trigger** starts a **run**: one execution of a task on a **runner**. A run never waits for you: it ends, and your later change on GitHub triggers the next run.

| Service | Product |
| --- | --- |
| Ticket tracker | GitHub Issues |
| Ticket source | none yet: people file tickets by hand |
| Git host | GitHub |
| Orchestrator | Foreman, a Grok Bot that starts runs through T3 Code's MCP. T3's thread list records the runs. |
| Runner | a new T3 Code thread in a new worktree on the always-on machine. A run never reuses an earlier thread. |
| Observability platform | none: T3's thread pages show enough |

| Task | Trigger | Triggers next | You re-enter | No duplicates |
| --- | --- | --- | --- | --- |
| Triage | someone else opens a ticket, or you label it `needs-triage` | nothing | you label the ticket | one "Factory triage:" comment per ticket |
| Decompose | you label a spec `ready-for-decompose` | Implement | you edit the new tickets | the label is removed as a claim |
| Implement | `ready-for-agent`, a merge, or weekdays 09:00 | Review | at Hand-off | the ticket is assigned as a claim |
| Review | a draft PR opens or gets commits | Rework or Hand-off | at Hand-off | one review per head commit |
| Rework | a FAIL review, or you label `needs-rework` | Review | `ready-for-human` after 2 rounds | one rework run per PR at a time |
| Hand-off | a PASS review | nothing | you add `approved` and merge | only draft PRs are handed off |
| Fix | a run ends with an error or without its result | Review | every fix PR needs your `approved` | one ticket per failed run; fixes never chain |
| Retro | every tenth merged PR in a repo | Review | at Hand-off | one retro run per repo at a time |
| Architecture | Mondays 08:00 | nothing | you label a candidate | one open candidates ticket per repo |

`foreman.md` spells out what each task does and which services it reads and writes.

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
- the `wayfinder:*` labels, and the factory's labels: `ready-for-decompose`, `needs-rework`, `approved` and `factory-fix`;
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
2. Add this repo as a T3 project too, so Fix and Retro runs can open PRs on `foreman.md`, and create the labels those PRs use:
   ```bash
   cd ~/Projects/software-factory && t3 project add .
   for l in approved needs-rework factory-fix; do gh label create "$l" --force; done
   ```
3. Create a Bot called Foreman. Paste the description from `foreman.md`. When a merged Fix or Retro PR changes `foreman.md`, paste it again.
4. Set Foreman's tool permissions:
   - **Blocked:** merging PRs, pushing code, deleting branches or repos.
   - **Needs approval:** closing issues.
   - **Always allow:** everything else.

Foreman must never add the `approved` label. Only you do, as the record that you reviewed the PR. GitHub won't let you approve a PR opened under your own account, so the label stands in for that approval.

## 4. Start slow

Every trigger speeds the factory up, so every one needs brakes. There are three:
- **Automated checks:** typecheck, lint and test in CI, required by the ruleset.
- **Automated review:** the Review task reads each PR cold, against the codebase and the ticket's acceptance scenarios.
- **Human review:** no PR merges without your `approved`. What you catch becomes a new check or a sharper review, through Retro or by hand.

Turn on one group of tasks per week:
1. **By hand.** In T3, run grill-with-docs, to-spec, to-tickets, implement and code-review yourself on 2–3 tickets. Run `/retro` after each one.
2. **Review, Rework and Hand-off.**
3. **Implement and Fix.** Implement starts with its throttle: at most 2 runs in flight and 6 a day.
4. **Decompose and Triage.**
5. **Architecture and Retro.**

Every loop is capped: 2 rework rounds per PR, then `ready-for-human`, and fixes never chain. Open a throttle only once the brakes have earned your trust.
