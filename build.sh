#!/usr/bin/env bash

ROOT="$(dirname "${BASH_SOURCE[0]}")"
echo "Source dir: $ROOT"
cd "$ROOT" || exit 1

FULL="$(mktemp)"
echo "Temp file: $FULL"

for f in "$ROOT"/data/*.lua; do
    cat "$f" >> "$FULL"
done

cat rpn.lua >> "$FULL"

if ! [[ -f "$ROOT/.luna/luna" ]]; then
    echo "Cloning luna..."
    git clone 'https://github.com/adriweb/Luna.git' .luna

    echo "Building luna..."
    (
        cd .luna || exit 1
        make
    )
fi

cp "$FULL" "$ROOT/rpn.full.lua"
"$ROOT/.luna/luna" "$FULL" "$ROOT/rpn.tns"
