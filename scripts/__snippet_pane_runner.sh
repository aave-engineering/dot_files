#!/usr/bin/env bash

set -eo pipefail

# Check if in tmux first
if [ -z "$TMUX" ]; then
    echo "Error: This script must be run from within a tmux session"
    exit 1
fi

# Get current directory
CURRENT_DIR=$(tmux display-message -p '#{pane_current_path}')

# Create a temporary directory for our fzf wrapper
WRAPPER_DIR=$(mktemp -d)

# Create an fzf wrapper that filters out links
cat > "$WRAPPER_DIR/fzf" << 'EOF'
#!/usr/bin/env bash
# Filter out lines starting with [Link to before passing to real fzf
# Add keybinding to launch tag browser
grep -v '^\[Link to' | /usr/local/bin/fzf \
    --bind "ctrl-g:execute(~/dev/dotfiles/scripts/__snippet_tag_browser.sh)+abort" \
    --header " ctrl-g: browse by tag" \
    "$@"
EOF

chmod +x "$WRAPPER_DIR/fzf"

# Add our wrapper to PATH before the real fzf
export PATH="$WRAPPER_DIR:$PATH"

# Now pet will use our wrapped fzf!
RESULT=$(pet search)

# Clean up
rm -rf "$WRAPPER_DIR"

if [ -n "$RESULT" ]; then
    # Check if the command starts with xdg-open
    if [[ "$RESULT" =~ ^xdg-open[[:space:]] ]]; then
        # Use tmux run-shell to execute in proper environment
        tmux run-shell "$RESULT && wmctrl -a Firefox"
        exit 0
    else
        # Create a new vertical split pane for other commands
        tmux split-window -v -c "$CURRENT_DIR"
        
        # Get the new pane ID
        NEW_PANE=$(tmux display-message -p '#{pane_id}')
        
        # Clear the new pane
        tmux send-keys -t "$NEW_PANE" "clear" C-m
        
        # Check if command has parameters (contains ?)
        if [[ "$RESULT" =~ \? ]]; then
            # Send command without executing, so user can edit parameters
            tmux send-keys -t "$NEW_PANE" "$RESULT"
        else
            # Execute command directly
            tmux send-keys -t "$NEW_PANE" "$RESULT" C-m
        fi
        
        # Focus on the new pane
        tmux select-pane -t "$NEW_PANE"
    fi
fi