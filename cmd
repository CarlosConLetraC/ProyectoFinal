#!/usr/bin/env bash

BASE_ARGS=(
    -l import/init
    -e "import('Math', 'Table', 'system'); print, _print = system.print, print"
    -i
)

exec luajit "${BASE_ARGS[@]}" -- --exec "$@;os.exit()"
