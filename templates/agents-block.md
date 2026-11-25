## Agent skills

### Issue tracker

GitHub Issues for this repo, through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Factory

- Quality bar: {{QUALITY}}
- Name branches `<type>/<issue>-<slug>` and write Conventional Commits.
- When `/implement` finishes, push the branch and open a draft PR with `/pr`. Put `Closes #<issue>` in its body.
- Never merge a PR, and never push to the default branch.
- Never commit with `--no-verify`. When the pre-commit check fails, fix the cause.
- `/code-review` uses `origin/<default branch>` as its fixed point. Its sub-agents must not run `/code-review` or start other agents.
- Never pick up an issue that has sub-issues: it is a spec, not a ticket.
