#!/usr/bin/env bash
# build_release.sh — apply a white-label brand, then build for release.
#
# Usage:  scripts/build_release.sh <slug> [apk|appbundle|ipa]
#
# Runs the brand applicator (codegen + assets + native patch + icons)
# then `flutter build`. Use on a clean / CI checkout — applying a
# non-default brand dirties native files.
set -euo pipefail

SLUG="${1:-default}"
TARGET="${2:-appbundle}"

cd "$(dirname "$0")/.."

echo "▶ Applying brand: ${SLUG}"
dart run tool/apply_brand.dart "${SLUG}"

echo "▶ flutter build ${TARGET} --release"
flutter build "${TARGET}" --release

echo "✓ Done — brand=${SLUG} target=${TARGET}"
