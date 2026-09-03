#!/usr/bin/env bash
# Link the ABS CURF CSVs into this folder without copying 700 MB of microdata.
# Safe to re-run.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$ROOT/data/original_data/all_files"
mkdir -p "$DEST"

candidates=(
  "$ROOT/../data/original_data/all_files"
  "$HOME/Desktop/STAT3888/data/original_data/all_files"
)

SRC=""
for c in "${candidates[@]}"; do
  if [[ -d "$c" ]] && ls "$c"/*.csv >/dev/null 2>&1; then
    SRC="$(cd "$c" && pwd)"
    break
  fi
done

if [[ -z "$SRC" ]]; then
  cat <<EOF
Could not find the AHS CURF CSVs.

Place them in one of:
  $DEST
  ../data/original_data/all_files   (if this repo sits inside STAT3888/)
  ~/Desktop/STAT3888/data/original_data/all_files

Required files include:
  AHSnpa11bp.csv  AHSnpa11bb.csv  AHSnpa11bf.csv  AHSnpa11bs.csv  AHSnpa11ba.csv
  AHSnhs11bsp.csv AHSnhs11bbi.csv AHSnhs11bhh.csv AHSnhs11bcn.csv
  plus the other AHSnhs11b* / inp13b* CSVs listed in File-2.variables.xlsx
EOF
  exit 1
fi

n=0
for f in "$SRC"/*.csv; do
  base="$(basename "$f")"
  target="$DEST/$base"
  if [[ -e "$target" || -L "$target" ]]; then
    continue
  fi
  ln -s "$f" "$target"
  n=$((n + 1))
done

echo "Linked $n CSV file(s) from:"
echo "  $SRC"
echo "into:"
echo "  $DEST"
echo "CSV count now: $(ls "$DEST"/*.csv 2>/dev/null | wc -l | tr -d ' ')"
