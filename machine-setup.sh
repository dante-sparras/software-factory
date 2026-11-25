#!/usr/bin/env bash
# Install Matt Pocock's skills, and only his, for every agent T3 Code runs on this machine.
#
#   machine-setup.sh            Show what would change. Changes nothing.
#   machine-setup.sh --apply    Park every other global skill, then install Matt's.
#   machine-setup.sh --install  Install or refresh Matt's skills only. Safe to schedule weekly.
#
# Parked skills are moved, not deleted, to ~/.skills-parked/<timestamp>/.
# To undo, move them back.
set -euo pipefail

AGENTS=(claude-code cursor grok antigravity-cli)
SKILL_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.cursor/skills"
  "${GROK_HOME:-$HOME/.grok}/skills"
  "$HOME/.gemini/antigravity-cli/skills"
  "$HOME/.gemini/config/skills"
  "$HOME/.agents/skills"
)
# Matt's promoted set is the one his Claude Code plugin ships.
# Reading it at run time picks up skills he adds later.
MANIFEST=https://raw.githubusercontent.com/mattpocock/skills/main/.claude-plugin/plugin.json

matt_skills() {
  curl -fsSL "$MANIFEST" | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () =>
      console.log(JSON.parse(s).skills.map(p => p.split("/").pop()).join(" ")))'
}

park_all() {
  local apply=$1 park found=0
  park="$HOME/.skills-parked/$(date +%Y%m%d-%H%M%S)"
  for dir in "${SKILL_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    for entry in "$dir"/* "$dir"/.[!.]*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      found=1
      local label=${dir#"$HOME"/}; label=${label//\//_}
      if [ "$apply" = 1 ]; then
        mkdir -p "$park/$label"
        mv "$entry" "$park/$label/"
      else
        echo "  would park  ${entry#"$HOME"/}"
      fi
    done
  done
  if [ "$apply" = 1 ] && [ "$found" = 1 ]; then echo "Parked old skills in $park"; fi
  if [ "$found" = 0 ]; then echo "  no global skills to park"; fi
}

install_matt() {
  local skills
  skills=$(matt_skills)
  echo "Installing for ${AGENTS[*]}: $skills"
  # shellcheck disable=SC2086
  npx -y skills@latest add mattpocock/skills -g -y -a "${AGENTS[@]}" -s $skills
}

case "${1:-}" in
  --apply)   park_all 1; install_matt ;;
  --install) install_matt ;;
  "")
    echo "Dry run. These global skills would be parked:"
    park_all 0
    echo "Then Matt's skills would be installed for ${AGENTS[*]}:"
    echo "  $(matt_skills)"
    echo "Run again with --apply to do it."
    ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac
