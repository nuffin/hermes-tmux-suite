#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DIR="$HERMES_HOME/skills/devops"

echo "hermes-tmux-suite installer"
echo ""

mkdir -p "$SKILLS_DIR"

for skill in tmux-delegate-task tmux-socket; do
  src="$SCRIPT_DIR/skills/$skill"
  dst="$SKILLS_DIR/$skill"
  [ ! -d "$src" ] && { echo "  ✗ Source not found: $src"; continue; }

  if [ "${1:-}" = "--symlink" ]; then
    [ -e "$dst" ] && rm -rf "$dst"
    ln -sfn "$src" "$dst"
    echo "  → Symlinked: $skill"
  else
    rm -rf "$dst"
    cp -r "$src" "$dst"
    echo "  ✓ Installed: $skill"
  fi
done

echo ""
echo "Done. Add to config.yaml:"
echo "  skills.config.skill-graph.source_dirs:"
echo "    - $SKILLS_DIR"
