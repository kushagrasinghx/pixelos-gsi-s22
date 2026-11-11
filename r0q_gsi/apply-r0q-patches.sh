#!/bin/bash
# Apply Doze-off's GSI patch set minus the other-manufacturer patches in patches-skip.txt.
# Builds a filtered copy of patches/ and runs Doze-off's own apply-patches.sh against it,
# so the apply logic stays identical to the official build.
# Usage: bash device/kushagra/r0q_gsi/apply-r0q-patches.sh   (from anywhere)
set -eu
LAYER="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$LAYER/../../.." && pwd)"
STAGE="$SRC/out-r0q-patchset"

cd "$SRC"
[ -d patches/trebledroid ] || { echo "patches/ missing - run setup-extra-repos.sh first"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -a patches "$STAGE/patches"

skipped=0
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs)"
  [ -z "$line" ] && continue
  if [ -f "$STAGE/patches/$line" ]; then
    rm -f "$STAGE/patches/$line"; skipped=$((skipped+1))
  else
    echo "WARN: skip entry not found: $line"
  fi
done < "$LAYER/patches-skip.txt"
echo "Skipping $skipped other-manufacturer patches."

# Doze-off's script expects <arg>/patches/{trebledroid,personal} and runs relative to $PWD.
bash patches/apply-patches.sh "$STAGE"

# r0q's own fixups (patches-local/<platform_repo_name>/*.patch), applied after Doze-off's set.
# They rebase kept patches that were written on top of a skipped other-manufacturer patch.
for dir in "$LAYER"/patches-local/*/; do
  repo="$(basename "$dir")"; repo="${repo#platform_}"; repo="${repo//_//}"
  for p in "$dir"*.patch; do
    if git -C "$SRC/$repo" am -q --3way "$p"; then echo "local: applied $(basename "$p") -> $repo"
    else git -C "$SRC/$repo" am --abort; echo "local: FAILED $(basename "$p") -> $repo"; fi
  done
done
rm -rf "$STAGE"
