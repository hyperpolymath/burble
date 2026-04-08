#!/bin/bash
# Sync lessons from Palimpsest PLASMA to PLASMA Framework

set -e

echo "🔄 Syncing Palimpsest PLASMA lessons to framework..."

# Read config
CONFIG_FILE=".plasma-sync"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

# Parse config (simple version)
FRAMEWORK_REPO="../../../plasma-framework"
OUTPUT_DIR="$FRAMEWORK_REPO/INTEGRATIONS/burble"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy patterns
echo "📝 Copying tooling patterns..."
cp tools/validate.sh "$OUTPUT_DIR/validate.example.sh"

echo "📋 Copying configuration..."
cp config.yml "$OUTPUT_DIR/config.example.yml"

# Create lessons document
echo "📚 Creating lessons document..."
cat > "$OUTPUT_DIR/INTEGRATION_NOTES.md" << EOF
# Integration Notes from Palimpsest PLASMA

## What We've Learned

### Tooling Patterns
- Simple validation scripts work well
- Git hooks prevent breaks early
- CI/CD enforcement catches edge cases

### Configuration Approach
- YAML is human and machine friendly
- Modular validation rules
- Clear separation of concerns

### Adoption Challenges
- Need better onboarding
- Documentation is key
- Start small, expand carefully

## Next Steps

1. Test these patterns in other contexts
2. Generalize the validation engine
3. Build better tooling around core concepts
4. Document integration patterns

## Attribution

These patterns come from Palimpsest PLASMA in the Burble project.
Maintainer: Jonathan D.A. Jewell
License: PMPL-1.0-or-later
EOF

echo "✅ Sync complete!"
echo "   Framework lessons updated in: $OUTPUT_DIR"
