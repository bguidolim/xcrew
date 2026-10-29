#!/bin/sh
# Runs `mcs pack validate` and fails on any error or warning. The one warning allowed is mcs's advice about a third-party
# tap the pack itself installs from: a formula only its tap publishes can't move.
# scripts/pack-validate.sh <pack directory>
set -eu
pack=$1
report=$(mktemp)
status=0
mcs pack validate "$pack" > "$report" 2>&1 || status=$?
cat "$report"
[ "$status" -eq 0 ] || exit "$status"
taps=$(sed -n "s|^ *brew: *\"\{0,1\}\([^/\" ]*/[^/\" ]*\)/[^/\" ]*\"\{0,1\} *$|\1|p" "$pack/techpack.yaml")
unexpected() {
  while IFS= read -r line; do
    for tap in $taps; do
      case $line in *"from third-party tap '$tap'"*) continue 2 ;; esac
    done
    printf '%s\n' "$line"
  done
}
warnings=$(grep '^\[WARN\]' "$report" | unexpected)
[ -z "$warnings" ] && exit 0
printf 'mcs pack validate warned; CI treats a warning as an error:\n%s\n' "$warnings" >&2
exit 1
