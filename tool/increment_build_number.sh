#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PUBSPEC_PATH="${PROJECT_ROOT}/pubspec.yaml"

if [[ ! -f "${PUBSPEC_PATH}" ]]; then
  echo "pubspec.yaml not found at: ${PUBSPEC_PATH}" >&2
  exit 1
fi

VERSION_LINE="$(grep -E '^version:[[:space:]]*' "${PUBSPEC_PATH}" | head -n1 || true)"

if [[ -z "${VERSION_LINE}" ]]; then
  echo "Could not find 'version:' in pubspec.yaml" >&2
  exit 1
fi

if [[ "${VERSION_LINE}" =~ ^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$ ]]; then
  APP_VERSION="${BASH_REMATCH[1]}"
  BUILD_NUMBER="${BASH_REMATCH[2]}"
else
  echo "Unsupported version format. Expected: version: x.y.z+N" >&2
  echo "Current line: ${VERSION_LINE}" >&2
  exit 1
fi

NEXT_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEXT_VERSION_LINE="version: ${APP_VERSION}+${NEXT_BUILD_NUMBER}"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "[DRY RUN] ${VERSION_LINE} -> ${NEXT_VERSION_LINE}"
  exit 0
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  sed -i '' -E \
    "s/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+[[:space:]]*$/version: ${APP_VERSION}+${NEXT_BUILD_NUMBER}/" \
    "${PUBSPEC_PATH}"
else
  sed -i -E \
    "s/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+[[:space:]]*$/version: ${APP_VERSION}+${NEXT_BUILD_NUMBER}/" \
    "${PUBSPEC_PATH}"
fi

echo "Build number incremented: ${BUILD_NUMBER} -> ${NEXT_BUILD_NUMBER}"
