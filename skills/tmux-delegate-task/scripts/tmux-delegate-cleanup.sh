#!/bin/bash
# tmux-delegate-cleanup — Close auto-created panes/windows after delegation completes.
# Usage: tmux-delegate-cleanup AUTO_PANE PANE KEEP AUTO_WINDOW SESSION WINDOW TMUX_FLAG
# All args correspond to the output of tmux-delegate-tail.sh.

AUTO_PANE="${1:-false}"
PANE="${2:-}"
KEEP="${3:-false}"
AUTO_WINDOW="${4:-false}"
SESSION="${5:-}"
WINDOW="${6:-}"
TMUX_FLAG="${7:-}"

if [ "$KEEP" = true ]; then
    exit 0
fi

if [ "$AUTO_PANE" = true ] && [ -n "$PANE" ]; then
    tmux $TMUX_FLAG kill-pane -t "$PANE" 2>/dev/null || true
fi

if [ "$AUTO_WINDOW" = true ] && [ -n "$SESSION" ] && [ -n "$WINDOW" ]; then
    WIN_IDX=$(tmux $TMUX_FLAG list-windows -t "$SESSION" \
        -F '#{window_index}' -f "#{==:#{window_name},$WINDOW}" 2>/dev/null)
    if [ -n "$WIN_IDX" ]; then
        PANE_COUNT=$(tmux $TMUX_FLAG list-panes -t "${SESSION}:${WIN_IDX}" 2>/dev/null | wc -l)
        if [ "$PANE_COUNT" -le 1 ]; then
            tmux $TMUX_FLAG kill-window -t "${SESSION}:${WIN_IDX}" 2>/dev/null || true
        fi
    fi
fi
