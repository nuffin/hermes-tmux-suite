[English](README.md) | [中文](README.zh.md)

# Hermes Tmux Suite

Tmux-integrated skill operations for [Hermes Agent](https://github.com/NousResearch/hermes-agent).

## What It Does

Dispatch a `delegate_task` subagent and automatically tail its live transcript in
a dedicated tmux pane — watch every step in real time without polluting your working panes.

## Skills

| Skill | Description |
|-------|-------------|
| `tmux-delegate-task` | Dispatch subagent + auto-tail transcript in tmux pane with auto-cleanup |
| `tmux-socket` | Detect active tmux socket and provide the correct `-L`/`-S` flag |

## Install

```bash
git clone https://github.com/nuffin/hermes-tmux-suite.git
cd hermes-tmux-suite
./install.sh              # copy to ~/.hermes/skills/devops/
./install.sh --symlink    # symlink for development
```

Or via pip:

```bash
pip install hermes-tmux-suite
```

## Usage

### tmux-delegate-task

In Hermes:

```
> run code review with tmux-delegate-task in the infra session, hermes window
```

The skill:
1. Dispatches `delegate_task` with your goal
2. Opens a tmux pane tailing the subagent's live transcript
3. Auto-closes the pane when done (unless you say `--keep`)

### Keep the Pane

By default, auto-created panes are closed when the delegation finishes. Add
`--keep` to leave the pane open for later review.

```
> run this with tmux-delegate-task, keep the pane after
> don't close the pane
> --keep
```

User-provided panes (`pane 3`) are never closed, regardless of `--keep`.

### tmux-socket

Detects the active tmux socket and provides the correct `-L` flag — useful when
constructing tmux commands in scripts or other skills.

```bash
# Inline one-liner for any script
TMUX_FLAG=$(if [ -n "$TMUX" ]; then \
  S=$(tmux display -p '#{socket_path}' 2>/dev/null); \
  N=$(basename "$S"); \
  [ "$N" != "default" ] && echo "-L $N"; \
fi)

# Then prefix all tmux commands
tmux $TMUX_FLAG new-session -d -s my-session
tmux $TMUX_FLAG send-keys -t my-session:0 "echo hello" Enter
```

| Socket | basename | TMUX_FLAG |
|--------|----------|-----------|
| `/tmp/tmux-1000/default` | `default` | `""` (empty) |
| `/tmp/tmux-1000/nested` | `nested` | `-L nested` |
| Not in tmux | — | `""` (empty) |

## Pane/Window Defaults

| You say... | session | window | pane |
|------------|---------|--------|------|
| (nothing) | current | current | split new |
| "infra session" | infra | new window | pane 0 |
| "infra session, hermes window" | infra | hermes | split new |
| "infra session, hermes window, pane 3" | infra | hermes | .3 (never close) |

## Repositories

| Role | Repo | PyPI |
|------|------|------|
| Skill code (this repo) | [hermes-tmux-suite](https://github.com/nuffin/hermes-tmux-suite) | — |
| Pip wrapper | [hermes-tmux-suite-pip](https://github.com/nuffin/hermes-tmux-suite-pip) | [hermes-tmux-suite](https://pypi.org/project/hermes-tmux-suite/) |
