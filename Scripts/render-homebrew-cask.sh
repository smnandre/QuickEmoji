#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:?Usage: render-homebrew-cask.sh VERSION SHA256 OUTPUT}
SHA256=${2:?Usage: render-homebrew-cask.sh VERSION SHA256 OUTPUT}
OUTPUT=${3:?Usage: render-homebrew-cask.sh VERSION SHA256 OUTPUT}

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'ERROR: VERSION must use stable X.Y.Z format.\n' >&2
    exit 64
fi

if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'ERROR: SHA256 must contain 64 lowercase hexadecimal characters.\n' >&2
    exit 64
fi

mkdir -p "$(dirname "$OUTPUT")"
sed \
    -e "s/__VERSION__/$VERSION/" \
    -e "s/__SHA256__/$SHA256/" \
    "$ROOT_DIR/Config/homebrew-cask.rb.template" >"$OUTPUT"
