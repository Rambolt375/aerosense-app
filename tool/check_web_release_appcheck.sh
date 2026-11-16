#!/usr/bin/env bash
# Fails if the App Check debug token can be enabled from a release web build.
#
# The debug provider is a local-development escape hatch: it disables App Check
# attestation. It must never be reachable in `build/web`, because App Check
# enforcement is what protects Firebase AI Logic (and the project quota) from
# abuse.
#
# Usage:
#   flutter build web --release --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=<key>
#   tool/check_web_release_appcheck.sh
set -euo pipefail

TOKEN='FIREBASE_APPCHECK_DEBUG_TOKEN'
BUILD_DIR='build/web'

# firebase_app_check_web always compiles its own WebDebugProvider branch, which
# assigns this browser global behind a provider type check. Those two statements
# are expected; anything else is a leak.
VENDOR_OCCURRENCES=2

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "error: $BUILD_DIR not found. Run 'flutter build web --release' first." >&2
  exit 1
fi

fail=0

count_token() {
  # grep exits 1 when nothing matches; that is a normal "clean" result here.
  local count
  count=$( { grep -o "$TOKEN" "$1" 2>/dev/null || true; } | wc -l )
  echo "$count" | tr -d ' '
}

index_count=$(count_token "$BUILD_DIR/index.html")
if [[ "$index_count" != "0" ]]; then
  echo "error: $BUILD_DIR/index.html contains $TOKEN." >&2
  echo "       The debug provider must only be set from kDebugMode code." >&2
  fail=1
fi

while IFS= read -r file; do
  count=$(count_token "$file")
  [[ "$count" == "0" ]] && continue

  if [[ "$file" == "$BUILD_DIR/main.dart.js" && "$count" == "$VENDOR_OCCURRENCES" ]]; then
    continue
  fi

  echo "error: $file contains $TOKEN ($count occurrence(s))." >&2
  fail=1
done < <(find "$BUILD_DIR" -type f)

if [[ "$fail" != "0" ]]; then
  echo "FAILED: the App Check debug token is reachable from the release bundle." >&2
  exit 1
fi

echo "OK: no App Check debug token outside the known vendor debug branch."
