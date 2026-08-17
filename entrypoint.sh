#!/bin/sh
# Point every piece of agent state at $GARCON_DATA_DIR so a single volume covers
# the lot. Paths without an env var override get symlinked; the first run copies
# whatever the image baked in, later runs leave the volume alone.
set -eu

DATA_DIR="${GARCON_DATA_DIR:-/data}"
HOME="${HOME:-/home/garcon}"

mkdir -p \
    "${DATA_DIR}/.garcon" \
    "${DATA_DIR}/.claude" \
    "${DATA_DIR}/.codex" \
    "${DATA_DIR}/.opencode" \
    "${DATA_DIR}/projects"

# link <dir-under-data> <path-under-home>
link() {
    target="${DATA_DIR}/$1"
    path="${HOME}/$2"

    [ -L "${path}" ] && return 0

    mkdir -p "${target}"
    if [ -d "${path}" ]; then
        cp -an "${path}/." "${target}/" 2>/dev/null || true
        rm -rf "${path}"
    fi
    mkdir -p "$(dirname "${path}")"
    ln -s "${target}" "${path}"
}

link .amp            .amp
link .config         .config
link opencode-data   .local/share/opencode
link opencode-state  .local/state/opencode
link opencode-cache  .local/cache/opencode

# oven/bun's own entrypoint handles arg normalisation.
exec /usr/local/bin/docker-entrypoint.sh "$@"
