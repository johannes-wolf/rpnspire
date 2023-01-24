#!/usr/bin/env bash

ROOT="$(dirname "${BASH_SOURCE[0]}")"

if ! [[ -f "$ROOT/.luna/luna" ]]; then
    echo "Cloning luna..."
    git clone 'https://github.com/ndless-nspire/Luna.git' .luna

    echo "Building luna..."
    (
        cd .luna || exit 1
        make
    )
fi

"$ROOT/.luna/luna" "bundle.lua" "$ROOT/rpn.tns"
