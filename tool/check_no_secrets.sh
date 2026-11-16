#!/usr/bin/env bash
# Fail if a TRACKED file contains a Google API key prefix.
#
# The Gemini keys for this competition build live only in env.json /
# env.android.json, which are gitignored and read at build time with
# --dart-define-from-file. They must never be committed.
#
# Three tracked files are intentional, public Firebase client configuration:
#   - lib/firebase_options.dart
#   - android/app/google-services.json
#   - firebaseEndpointReference.js (unused reference snippet)
# Firebase client API keys identify the project and are embedded in every
# client build by design. All other tracked files must stay clean.
#
# Run from anywhere: the script resolves the repository root itself.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Split the prefix so this script does not match itself.
prefix='AI''za'

hits="$(
  git grep -nI -e "$prefix" -- . \
    ':(exclude)lib/firebase_options.dart' \
    ':(exclude)android/app/google-services.json' \
    ':(exclude)firebaseEndpointReference.js' || true
)"

if [[ -n "$hits" ]]; then
  printf '%s\n' "$hits" >&2
  printf '\nFAIL: a Google API key prefix appears in a tracked file.\n' >&2
  printf 'Move the key to env.json or env.android.json and rotate it.\n' >&2
  exit 1
fi

printf 'OK: no Google API keys in tracked files.\n'
