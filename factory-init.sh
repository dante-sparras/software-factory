#!/usr/bin/env bash
# Put one or more repos on the factory. Safe to re-run.
#
#   factory-init.sh [options] <repo-path>...
#
#   --refresh       Overwrite docs/agents/*.md with Matt's latest templates.
#   --no-pr         Commit on the setup branch locally. Don't push or open a PR.
#   --skip-github   Don't touch labels, topics or rulesets (for offline testing).
#   --no-t3         Don't add the repo as a T3 Code project.
#
# For each repo this does what /setup-matt-pocock-skills does when you pick
# GitHub, the default labels and single-context, then adds the factory's
# guardrails. File changes go to a `chore/factory-setup` branch in a separate
# worktree, so your checkout isn't touched, and arrive as a PR.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
SEEDS=https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills
BRANCH=chore/factory-setup
REFRESH=0 OPEN_PR=1 GITHUB=1 T3=1
START='<!-- software-factory:start -->' END='<!-- software-factory:end -->'

LABELS=(
  "needs-triage|d4c5f9|Maintainer needs to evaluate this issue"
  "needs-info|fbca04|Waiting on reporter for more information"
  "ready-for-agent|0e8a16|Fully specified, ready for an AFK agent"
  "ready-for-human|1d76db|Requires human implementation"
  "wontfix|ffffff|Will not be actioned"
  "wayfinder:map|5319e7|Wayfinder map: Notes, Decisions so far, Fog"
  "wayfinder:research|c5def5|Wayfinder ticket: research"
  "wayfinder:prototype|c5def5|Wayfinder ticket: prototype"
  "wayfinder:grilling|c5def5|Wayfinder ticket: grilling"
  "wayfinder:task|c5def5|Wayfinder ticket: task"
)

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
warn() { printf '  \033[33m! %s\033[0m\n' "$*"; }
# Node on Windows needs C:/... paths, not Git Bash's /c/... paths.
native() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi; }

# Put the factory block into AGENTS.md, replacing an earlier copy or an
# unmarked `## Agent skills` section left by a manual setup run.
write_agents_block() {
  local file=$1
  node - "$file" "$(native "$KIT/templates/agents-block.md")" "$START" "$END" <<'JS'
const fs = require("fs");
const [file, blockPath, start, end] = process.argv.slice(2);
const block = `${start}\n${fs.readFileSync(blockPath, "utf8").replace(/\r\n/g, "\n").trim()}\n${end}\n`;
let text = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
const eol = text.includes("\r\n") ? "\r\n" : "\n";
text = text.replace(/\r\n/g, "\n");
const marked = new RegExp(`${start}[\\s\\S]*?${end}\\n?`);
if (marked.test(text)) {
  text = text.replace(marked, block);
} else {
  text = text.replace(/^## Agent skills\n[\s\S]*?(?=^## |(?![\s\S]))/m, "");
  text = (text.trimEnd() ? text.trimEnd() + "\n\n" : "") + block;
}
fs.writeFileSync(file, text.replace(/\n/g, eol));
JS
}

# AGENTS.md is the one file every provider reads. Claude Code reads CLAUDE.md,
# so CLAUDE.md imports AGENTS.md.
setup_instructions() {
  if [ -f CLAUDE.md ] && [ ! -f AGENTS.md ]; then
    git mv CLAUDE.md AGENTS.md
    echo "  moved CLAUDE.md to AGENTS.md"
  fi
  write_agents_block AGENTS.md
  if [ ! -f CLAUDE.md ]; then
    printf '@AGENTS.md\n' > CLAUDE.md
  elif ! grep -qx '@AGENTS.md' CLAUDE.md; then
    printf '@AGENTS.md\n\n%s' "$(cat CLAUDE.md)" > CLAUDE.md
    grep -q '^## Agent skills' CLAUDE.md && warn "CLAUDE.md still has its own '## Agent skills' section; delete it"
  fi
  echo "  AGENTS.md has the Agent skills and Factory sections; CLAUDE.md imports it"
}

setup_docs() {
  mkdir -p docs/agents
  local pair src dst
  for pair in issue-tracker-github.md:issue-tracker.md triage-labels.md:triage-labels.md domain.md:domain.md; do
    src=${pair%%:*} dst=docs/agents/${pair##*:}
    if [ -f "$dst" ] && [ "$REFRESH" = 0 ]; then echo "  kept $dst"; continue; fi
    curl -fsSL "$SEEDS/$src" -o "$dst"
    echo "  wrote $dst"
  done
}

setup_ci() {
  if [ -f .github/workflows/ci.yml ] || [ -f .github/workflows/ci.yaml ]; then
    echo "  kept existing CI workflow"
  elif [ -f package.json ]; then
    mkdir -p .github/workflows
    cp "$KIT/templates/ci-node.yml" .github/workflows/ci.yml
    echo "  added .github/workflows/ci.yml (typecheck, lint, test)"
  else
    warn "no package.json: add a CI workflow with a job called 'ci' yourself"
  fi
}

has_ci_job() {
  grep -qsE '^  ci:' .github/workflows/ci.yml .github/workflows/ci.yaml
}

setup_github() {
  local slug=$1 default=$2 l name color desc
  for l in "${LABELS[@]}"; do
    IFS='|' read -r name color desc <<<"$l"
    gh label create "$name" --repo "$slug" --color "$color" --description "$desc" --force >/dev/null
  done
  echo "  labels: 5 triage + 5 wayfinder"

  gh repo edit "$slug" --add-topic factory --delete-branch-on-merge >/dev/null
  echo "  topic 'factory' added (Foreman only works in repos with this topic)"

  # Ruleset on the default branch: no direct pushes, no force pushes, no
  # deletion, and the `ci` check must pass once a CI workflow exists.
  local checks=""
  if has_ci_job; then
    checks=',{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,"required_status_checks":[{"context":"ci"}]}}'
  fi
  local body
  body=$(cat <<JSON
{"name":"factory","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"},
  {"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}}$checks]}
JSON
)
  local id
  id=$(gh api "repos/$slug/rulesets" --jq '.[] | select(.name=="factory") | .id' 2>/dev/null || true)
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$slug/rulesets/$id" --input - <<<"$body" >/dev/null && echo "  ruleset 'factory' updated on $default"
  elif gh api -X POST "repos/$slug/rulesets" --input - <<<"$body" >/dev/null 2>&1; then
    echo "  ruleset 'factory' created on $default"
  else
    warn "couldn't create the ruleset (private repos on GitHub Free don't support rulesets)"
  fi
  if [ -z "$checks" ]; then warn "the ruleset doesn't require CI yet; re-run after a 'ci' job exists"; fi
}

t3_add() {
  local path=$1 t3
  t3=$(command -v t3 || command -v t3.cmd || true)
  if [ -z "$t3" ]; then warn "t3 not found; add the project in T3 by hand"; return; fi
  if "$t3" project add "$path" >/dev/null 2>&1; then echo "  added to T3"; else echo "  T3: already a project, or the server isn't running"; fi
}

init_repo() {
  local repo
  say "$1"
  if ! repo=$(cd "$1" && git rev-parse --show-toplevel 2>/dev/null); then
    warn "not a git repo, skipped"; return
  fi
  cd "$repo"

  local slug="" default
  if [ "$GITHUB" = 1 ]; then
    if ! slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null); then
      warn "no GitHub repo behind this checkout, skipped"; return
    fi
    default=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
    git fetch -q origin "$default"
    base="origin/$default"
  else
    default=$(git symbolic-ref --short HEAD)
    base=$default
  fi

  local wt
  wt=$(mktemp -d)/factory-setup
  git worktree prune
  trap 'git -C "$repo" worktree remove --force "$wt" 2>/dev/null || true' EXIT
  if git show-ref -q --verify "refs/heads/$BRANCH"; then
    git worktree add -q "$wt" "$BRANCH"
  else
    git worktree add -q -b "$BRANCH" "$wt" "$base"
  fi

  (
    cd "$wt"
    setup_docs
    setup_instructions
    setup_ci
    if [ "$GITHUB" = 1 ]; then setup_github "$slug" "$default"; fi
    git add -A
    if git diff --cached --quiet; then
      echo "  no file changes"
    else
      git commit -q -m "chore: set up software factory" \
        -m "Configure Matt Pocock's skills (GitHub tracker, default labels, single-context) and the factory guardrails."
      if [ "$OPEN_PR" = 1 ] && [ "$GITHUB" = 1 ]; then
        git push -q -u origin "$BRANCH"
        gh pr view "$BRANCH" --json url --jq .url 2>/dev/null ||
          gh pr create --head "$BRANCH" --base "$default" --title "chore: set up software factory" \
            --body "Adds \`docs/agents/\` from Matt Pocock's \`setup-matt-pocock-skills\` templates, the \`## Agent skills\` and \`## Factory\` sections in \`AGENTS.md\`, and CI where missing. Labels, the \`factory\` topic and the branch ruleset were applied directly."
      else
        echo "  committed on branch $BRANCH (not pushed)"
      fi
    fi
  )
  git worktree remove --force "$wt"
  trap - EXIT
  if [ "$T3" = 1 ]; then t3_add "$repo"; fi
}

repos=()
for arg in "$@"; do
  case "$arg" in
    --refresh) REFRESH=1 ;;
    --no-pr) OPEN_PR=0 ;;
    --skip-github) GITHUB=0 ;;
    --no-t3) T3=0 ;;
    -*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) repos+=("$(cd "$arg" && pwd)") ;;
  esac
done
[ ${#repos[@]} -gt 0 ] || { sed -n '2,14p' "$0"; exit 2; }
for r in "${repos[@]}"; do init_repo "$r"; done
