#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Bebop codegen gate.
#
# The Elixir codecs in server/lib/burble/protocol/ derive from the .bop schemas
# in server/priv/schemas/ via `mix bebop.generate`. Nothing re-ran the generator
# in CI, so nobody noticed it had stopped working at all.
#
# TWO CHECKS, both ARMED:
#
#   CHECK A (HARD FAIL) — the generator must parse every committed schema and
#     emit output. This is what catches the failure found on 2026-07-28:
#     `mix bebop.generate` crashed with `binary_part("}\n", 0, 173)` in
#     find_matching_close/3 — the codecs could not be reproduced from their own
#     sources at all.
#
#   CHECK B (HARD FAIL — armed 2026-08-04 per owner ruling A7) — byte-identity
#     between regenerated output and the committed files. The generator now
#     emits the documentation that used to be hand-maintained (moduledoc
#     wire-format tables derived from the schema's /// doc comments, banner
#     sections, per-function @doc), so the committed codecs ARE the generator's
#     output and any schema/codec desync fails the build. Edit the .bop or the
#     generator, run `mix bebop.generate`, commit the result — never edit
#     lib/burble/protocol/ by hand.
#
# Usage: scripts/check-bebop-codegen.sh
set -uo pipefail

cd "$(dirname "$0")/../server"

OUT_DIR="lib/burble/protocol"
[ -d "$OUT_DIR" ] || { echo "::error::missing $OUT_DIR"; exit 1; }

SNAPSHOT="$(mktemp -d)"
restore() {
  # Always put the committed files back: the gate must never mutate the tree.
  rm -rf "${OUT_DIR:?}/"*
  cp -a "$SNAPSHOT/." "$OUT_DIR/"
  rm -rf "$SNAPSHOT"
}
trap restore EXIT
cp -a "$OUT_DIR/." "$SNAPSHOT/"

echo "== CHECK A: the generator must run against priv/schemas/ =="
if ! mix bebop.generate; then
  cat >&2 <<'MSG'
::error::Bebop generator FAILED. The committed codecs cannot be reproduced from
their own schemas. Either a schema uses syntax the parser cannot handle, or the
generator has regressed. Fix server/lib/mix/tasks/bebop_gen.ex (or the schema)
before relying on anything in lib/burble/protocol/.
MSG
  exit 1
fi
echo "PASS: generator parsed every schema and emitted output"

echo
echo "== CHECK B (ARMED): regenerated output must be byte-identical =="
if diff -ru "$SNAPSHOT" "$OUT_DIR"; then
  echo "PASS: regenerated output is byte-identical to the committed codecs."
else
  cat >&2 <<'MSG'
::error::Committed codecs are NOT what `mix bebop.generate` produces (diff
above). Either the schema or the generator changed without regenerating, or
someone edited lib/burble/protocol/ by hand. Fix: run `mix bebop.generate`
inside server/ and commit the result.
MSG
  exit 1
fi

exit 0
