#!/usr/bin/env bash
# Test script to verify launcher works

echo "Testing Burble launcher..."

# Test the desktop shortcut path
echo "Desktop shortcut points to: $(grep 'Exec=' ~/Desktop/burble-voice.desktop | head -1 | cut -d= -f2)"

# Test the launcher script exists
if [ -f "/var/mnt/eclipse/repos/burble/scripts/burble-launcher.sh" ]; then
    echo "✓ Launcher script exists"
    chmod +x /var/mnt/eclipse/repos/burble/scripts/burble-launcher.sh
else
    echo "✗ Launcher script missing"
fi

# Test the run.sh wrapper
if [ -f "/var/mnt/eclipse/repos/burble/run.sh" ]; then
    echo "✓ run.sh wrapper exists"
    chmod +x /var/mnt/eclipse/repos/burble/run.sh
else
    echo "✗ run.sh wrapper missing"
fi

echo "Launcher setup complete!"
