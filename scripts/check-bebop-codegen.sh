#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Bebop codegen gate.
#
# The Elixir codecs in server/lib/burble/protocol/ derive from the .bop schemas
# in server/priv/schemas/ via `mix bebop.generate`. Nothing re-ran the generator
# in CI, so nobody noticed it had stopped working at all.
#
# TWO CHECKS, deliberately different strengths — read this before "tightening"
# the second one:
#
#   CHECK A (HARD FAIL) — the generator must parse every committed schema and
#     emit output. Armed. This is what catches the failure found on 2026-07-28:
#     `mix bebop.generate` crashed with `binary_part("}\n", 0, 173)` in
#     find_matching_close/3 — the codecs could not be reproduced from their own
#     sources at all.
#
#   CHECK B (REPORT ONLY — NOT ARMED) — byte-identity between regenerated
#     output and the committed files. It CANNOT pass today, and not because of
#     schema drift: the committed codecs were generated once and then ENRICHED
#     BY HAND (wire-format table in the moduledoc, per-function @doc strings,
#     banner comments, reordered clauses). Arming it as-is would force a
#     regeneration that DELETES that hand-written documentation.
#
#     Resolving it is an owner decision, one of:
#       (1) accept the loss — regenerate, commit the leaner output, arm Check B;
#       (2) teach the generator to emit the richer docs, then arm Check B;
#       (3) keep the codecs hand-maintained and retire the generator — then
#           delete Check A too and say so in the schemas' README.
#     Until then this prints the diff so drift stays visible, and exits 0.
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
echo "== CHECK B (report only, NOT armed — see header): byte-identity =="
if diff -ru "$SNAPSHOT" "$OUT_DIR"; then
  echo "PASS: regenerated output is byte-identical to the committed codecs."
  echo "NOTE: Check B now passes. If that is expected, arm it by making this"
  echo "      branch exit 1 on diff, and delete this notice."
else
  echo
  echo "::warning::Regenerated output differs from the committed codecs (diff"
  echo "above). Expected while the hand-enrichment question is open — this does"
  echo "NOT fail the build. See the header of this script."
fi

exit 0
