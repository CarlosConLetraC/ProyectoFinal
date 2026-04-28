# se recomienda agregar estas funciones a su .bashrc

podmanbuild() {
    if [ -z "$1" ]; then
        echo "Uso: podmanbuild <dockerfile> [tag]"
        return 1
    fi

    local dockerfile="$1"
    local tag="${2:-ml-proyecto}"

    if [ ! -f "$dockerfile" ]; then
        echo "[ERROR] No existe: $dockerfile"
        return 1
    fi

    echo "[INFO] Build: $tag <- $dockerfile"

    podman build -t "$tag" -f "$dockerfile" .
}

podmanrun() {
    oldPWD="$(pwd)"
    cd ~

    if [ -z "$1" ]; then
        echo "Uso: podmanrun <imagen>"
        return 1
    fi

    local image="$1"

    podman run -it \
        --userns=keep-id \
        -v "$(pwd)":/home/pc:Z \
        -w /home/pc \
        "$image"

    cd "$oldPWD"
}
