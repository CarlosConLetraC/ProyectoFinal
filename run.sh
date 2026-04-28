#!/usr/bin/env bash
set -euo pipefail

function prettyprint() {
	local level=$1
	shift
	local packed=("$@")

	case $level in
		0)
			printf "\e[0;36m[INFO]:\e[0m %s\n" "${packed[*]}"
		;;
		1)
			printf "\e[0;33m[WARN]:\e[0m %s\n" "${packed[*]}"
		;;
		2|*)
			printf "\e[0;31m[FAIL]:\e[0m %s\n" "${packed[*]}"
		;;
	esac
}

if ! command -v luajit >/dev/null 2>&1; then
	prettyprint 1 "LuaJIT no encontrado"

	if [ ! -d "entorno" ]; then
		prettyprint 0 "creando entorno. . ."
		./configurarentorno.sh
	else
		prettyprint 0 "entorno existe, intentando actualizar. . ."
		./configurarentorno.sh
	fi
fi

[ -x ./backend ] || ./build.sh
source "$PWD/entorno/bin/activate"

./runclient program.main.lua
./backend daemons
./runclient merge.lua
rm -rf daemons/*
python actividad_parte1.py