#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Bebop codegen drift gate.
#
# The Elixir codecs in server/lib/burble/protocol/ are GENERATED from the
# .bop schemas in server/priv/schemas/ by `mix bebop.generate`. Nothing
# re-ran that generator in CI, so editing a schema silently desynced the
# committed output — the schema and the bytes on the wire could disagree
# with nothing to notice.
#
# This gate re-runs the generator against the committed schemas and fails if
# the result differs from what is checked in. Same shape as gossamer's
# `gen-abi-foreign.sh --check`.
#
# Usage: scripts/check-bebop-codegen.sh
set -euo pipefail

cd "$(dirname "$0")/../server"

OUT_DIR="lib/burble/protocol"
[ -d "$OUT_DIR" ] || { echo "::error::missing $OUT_DIR"; exit 1; }

# Snapshot the committed output, regenerate, diff, then always restore.
SNAPSHOT="$(mktemp -d)"
trap 'rm -rf "$SNAPSHOT"' EXIT
cp -a "$OUT_DIR/." "$SNAPSHOT/"

echo "== regenerating codecs from priv/schemas/ =="
mix bebop.generate

fail=0
if ! diff -ru "$SNAPSHOT" "$OUT_DIR"; then
  fail=1
fi

# Restore the committed files so the gate never mutates the working tree.
rm -rf "${OUT_DIR:?}/"*
cp -a "$SNAPSHOT/." "$OUT_DIR/"

if [ "$fail" -ne 0 ]; then
  cat >&2 <<'MSG'
::error::Bebop codegen drift: lib/burble/protocol/ does not match what
`mix bebop.generate` produces from priv/schemas/. A .bop schema was edited
without regenerating, or the generated files were hand-edited.
Fix: cd server && mix bebop.generate, then commit the result.
MSG
  exit 1
fi

echo "PASS: generated codecs match priv/schemas/ (no drift)"
