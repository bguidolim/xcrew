#!/bin/sh
# Runs `mcs pack validate` and fails on any error or warning. The one warning allowed is mcs's advice about a third-party
# tap the pack itself installs from: a formula only its tap publishes can't move.
# scripts/pack-validate.sh <pack directory>
set -eu
pack=$1
status=0
report=$(mcs pack validate "$pack" 2>&1) || status=$?
printf '%s\n' "$report"
[ "$status" -eq 0 ] || exit "$status"
allowed=$(sed -n "s|^ *brew: *\"\{0,1\}\([^/]*/[^/]*\)/.*|from third-party tap '\1'|p" "$pack/techpack.yaml")
warnings=$(printf '%s\n' "$report" | grep '^\[WARN\]' | grep -vF "${allowed:-//none//}" || true)
[ -z "$warnings" ] && exit 0
printf 'mcs pack validate warned; CI treats a warning as an error:\n%s\n' "$warnings" >&2
exit 1
