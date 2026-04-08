#!/bin/bash
# PLASMA Validation Script for Burble

set -e

echo "🔍 Validating PLASMA documentation integrity..."

# Check for PLASMA headers in key documents
KEY_DOCS=(
  "../../../README.adoc"
  "../../../EXPLAINME.adoc"
  "../../../docs/architecture/ARCHITECTURE.adoc"
)

for doc in "${KEY_DOCS[@]}"; do
  if [ ! -f "$doc" ]; then
    echo "⚠️  Missing document: $doc"
    continue
  fi
  
  if ! grep -q "plasma:" "$doc"; then
    echo "❌ Missing PLASMA header in: $doc"
    exit 1
  fi
  
  echo "✅ PLASMA header found in: $doc"
done

# Check license compatibility
echo "📜 Checking license compatibility..."
if ! grep -q "SPDX-License-Identifier" ../../../README.adoc; then
  echo "❌ Missing license identifier"
  exit 1
fi

echo "✅ All PLASMA checks passed!"
