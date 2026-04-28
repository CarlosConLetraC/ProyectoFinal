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


prettyprint 0 "Iniciando instalacion. . ."

export MAKEFLAGS="-j$(nproc || echo 2)"
export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"

BASE_PATH="$PWD"
LUAROCKS_VERSION="3.13.0"

source /etc/os-release
OS=$ID
CODENAME="${VERSION_CODENAME:-}"

if [ -z "$CODENAME" ]; then
	prettyprint 2 " VERSION_CODENAME vacio."
	exit 1
fi

prettyprint 0 "OS: $OS ($CODENAME)"

mongod --version > /dev/null 2>&1 && MONGOD_INSTALADO=0 || MONGOD_INSTALADO=1
luarocks --version > /dev/null 2>&1 && LUAROCKS_INSTALADO=0 || LUAROCKS_INSTALADO=1

dependencies=(
	luajit wget curl make cmake gfortran gcc g++ build-essential pkg-config
	libssl-dev zlib1g-dev ca-certificates git
	libproj-dev libgeos-dev libgdal-dev
	libblas-dev liblapack-dev
	libwebp-dev protobuf-compiler libprotobuf-dev
	libluajit-5.1-dev libssh2-1-dev
	librsvg2-dev libcurl4-openssl-dev libxml2-dev
	libgit2-dev libjpeg-dev libtiff5-dev libpng-dev
	libfribidi-dev libharfbuzz-dev libcairo2-dev libfontconfig1-dev
	libreadline-dev libncurses-dev unzip zip
	python3-venv python3-pip python3-full
)

if [ "$OS" = "ubuntu" ]; then
	dependencies+=(libfreetype6-dev)
elif [ "$OS" = "debian" ]; then
	dependencies+=(libfreetype-dev)
else
	prettyprint 2 "Distribucion no soportada: $OS"
	exit 1
fi

prettyprint 0 "Instalando dependencias. . ."
sudo apt-get update
sudo apt-get install -y "${dependencies[@]}"

if [ "$LUAROCKS_INSTALADO" -ne 0 ]; then
	prettyprint 0 "Instalando LuaRocks $LUAROCKS_VERSION. . ."

	cd /tmp || exit 1
	rm -rf "luarocks-$LUAROCKS_VERSION"

	wget -q "https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz"
	tar zxf "luarocks-$LUAROCKS_VERSION.tar.gz"
	cd "luarocks-$LUAROCKS_VERSION"

	./configure \
		--with-lua-include=/usr/include/luajit-2.1 \
		--with-lua-bin=/usr/bin \
		--lua-suffix=jit \
		--lua-version=5.1

	make
	sudo make install
	cd ..

	rm -rf "luarocks-$LUAROCKS_VERSION"
fi

prettyprint 0 "Instalando paquetes Lua. . ."
sudo luarocks install luasocket || true
sudo luarocks install luasec || true

if [ ! -f "$BASE_PATH/import/Linux/ssh.so" ]; then
	prettyprint 0 "Compilando lua-ssh. . ."

	cd /tmp
	rm -rf lua-ssh
	git clone https://github.com/esno/lua-ssh.git
	cd lua-ssh/src

	gcc -O2 -fPIC -I/usr/include/luajit-2.1 -c ssh.c -o ssh.o
	gcc -shared -o ssh.so ssh.o -lluajit-5.1 $(pkg-config --libs libssh2 || echo "-lssh2")

	mkdir -p "$BASE_PATH/import/Linux/"
	cp ssh.so "$BASE_PATH/import/Linux/"

	cd /tmp
	rm -rf lua-ssh
fi

prettyprint 0 "Compilando clibs/*.c . . ."

CLIBS_DIR="$BASE_PATH/clibs"
OUT_DIR="$BASE_PATH/import/Linux"

mkdir -p "$OUT_DIR"

if [ ! -d "$CLIBS_DIR" ]; then
	prettyprint 2 "No existe o no se pudo crear directorio clibs/"
	exit 1
else
	for src in "$CLIBS_DIR"/*.c; do
		[ -e "$src" ] || continue

		name=$(basename "$src" .c)
		out="$OUT_DIR/$name.so"
		prettyprint 0 "Compilando $name. . ."
		gcc -O3 -fPIC \
			-I/usr/include/luajit-2.1 \
			-shared "$src" \
			-o "$out" \
			-lluajit-5.1 \
			$(pkg-config --cflags --libs lua5.1 2>/dev/null || echo "")
		if [ $? -eq 0 ]; then
			prettyprint 0 "OK: $name.so generado"
		else
			prettyprint 2 "Fallo compilando $name"
		fi
	done
fi

prettyprint 0 "Compilando cpplibs/*.cpp . . ."
CPPLIBS_DIR="$BASE_PATH/cpplibs"

if [ -d "$CPPLIBS_DIR" ]; then
	for src in "$CPPLIBS_DIR"/*.cpp; do
		[ -e "$src" ] || continue

		name=$(basename "$src" .cpp)
		out="$OUT_DIR/$name.so"

		prettyprint 0 "Compilando $name (C++). . ."

		g++ -O3 -fPIC \
			-I/usr/include/luajit-2.1 \
			-shared "$src" \
			-o "$out" \
			-lluajit-5.1 \
			-lstdc++ \
			$(pkg-config --cflags --libs luajit 2>/dev/null || echo "")

		if [ $? -eq 0 ]; then
			prettyprint 0 "OK: $name.so generado"
		else
			prettyprint 2 "Fallo compilando $name"
		fi
	done
else
	prettyprint 2 "No existe o no se pudo crear directorio cpplibs/"
	exit 1
fi

prettyprint 0 "Configurando entorno Python. . ."

VENV_PATH="$BASE_PATH/entorno"

export TMPDIR="$BASE_PATH/.tmp"
mkdir -p "$TMPDIR"

prettyprint 0 "Asegurando estado consistente de dpkg. . ."
sudo dpkg --configure -a

if [ -d "$VENV_PATH" ]; then
    prettyprint 1 "Entorno ya existe, verificando integridad. . ."

    if [ ! -f "$VENV_PATH/bin/python" ]; then
        prettyprint 1 "Entorno corrupto (sin python), recreando. . ."
        rm -rf "$VENV_PATH"
    fi
fi

if [ ! -d "$VENV_PATH" ]; then
    prettyprint 0 "Creando entorno virtual. . ."

    for i in 1 2 3; do
        if python3 -m venv "$VENV_PATH"; then
            break
        else
            prettyprint 1 "Fallo creando venv (intento $i), reintentando. . ."
            rm -rf "$VENV_PATH"
            sleep 2
        fi
    done

    if [ ! -f "$VENV_PATH/bin/python" ]; then
        prettyprint 2 "No se pudo crear el entorno virtual"
        exit 1
    fi
fi

prettyprint 0 "Verificando pip dentro del entorno. . ."

if ! "$VENV_PATH/bin/python" -m pip --version > /dev/null 2>&1; then
    prettyprint 1 "pip no esta disponible, recreando entorno. . ."
    rm -rf "$VENV_PATH"
    for i in 1 2 3; do
        if python3 -m venv "$VENV_PATH"; then
            if "$VENV_PATH/bin/python" -m pip --version > /dev/null 2>&1; then
                break
            fi
        fi
        prettyprint 1 "pip sigue sin existir (intento $i), reintentando. . ."
        rm -rf "$VENV_PATH"
        sleep 2
    done

    if ! "$VENV_PATH/bin/python" -m pip --version > /dev/null 2>&1; then
        prettyprint 2 "No se pudo crear un entorno con pip funcional"
        exit 1
    fi
fi

prettyprint 0 "Actualizando herramientas base. . ."

"$VENV_PATH/bin/python" -m pip install --upgrade pip setuptools wheel
if ! "$VENV_PATH/bin/python" -m pip --version > /dev/null 2>&1; then
    prettyprint 2 "pip quedo en estado invalido despues del upgrade"
    exit 1
fi

prettyprint 0 "Instalando dependencias Python. . ."
"$VENV_PATH/bin/python" -m pip install --upgrade pymongo matplotlib pandas numpy scikit-learn umap-learn plotly dash seaborn

prettyprint 0 "Instalacion completada correctamente."

if [ ! -d "$BASE_PATH/data/train.csv" ]; then
	cd "$BASE_PATH/data"
	unzip train.csv.zip
	cd -
fi
