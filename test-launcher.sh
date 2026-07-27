#!/usr/bin/env bash
# Test script to verify launcher works
set -uo pipefail

# Resolve paths relative to this script, not to a machine-specific absolute root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Testing Burble launcher..."

rc=0

# Test the desktop shortcut path (informational — the entry may not be installed)
desktop_file="$HOME/Desktop/burble-voice.desktop"
if [ -f "$desktop_file" ]; then
    echo "Desktop shortcut points to: $(grep 'Exec=' "$desktop_file" | head -1 | cut -d= -f2-)"
else
    echo "· no desktop shortcut installed at $desktop_file (run --integ to create one)"
fi

# Test the launcher script exists
if [ -f "$REPO_ROOT/burble-launcher.sh" ]; then
    echo "✓ Launcher script exists"
    chmod +x "$REPO_ROOT/burble-launcher.sh"
else
    echo "✗ Launcher script missing: $REPO_ROOT/burble-launcher.sh"
    rc=1
fi

# Test the run.sh wrapper
if [ -f "$REPO_ROOT/run.sh" ]; then
    echo "✓ run.sh wrapper exists"
    chmod +x "$REPO_ROOT/run.sh"
else
    echo "✗ run.sh wrapper missing: $REPO_ROOT/run.sh"
    rc=1
fi

if [ "$rc" -eq 0 ]; then
    echo "Launcher setup complete!"
else
    echo "Launcher setup INCOMPLETE — see ✗ above"
fi
exit "$rc"
