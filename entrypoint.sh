#!/bin/sh
# Point every piece of agent state at $GARCON_DATA_DIR so a single volume covers
# the lot. Paths without an env var override get symlinked; the first run copies
# whatever the image baked in, later runs leave the volume alone.
set -eu

DATA_DIR="${GARCON_DATA_DIR:-/data}"
HOME="${HOME:-/home/garcon}"

# The image runs as uid 1000; a volume owned by anyone else otherwise surfaces
# as a bare "mkdir: permission denied" several lines down.
if [ ! -w "${DATA_DIR}" ]; then
    echo "garcon: ${DATA_DIR} is not writable by $(id -un) (uid $(id -u), gid $(id -g))." >&2
    echo "garcon: on Kubernetes set securityContext.fsGroup: 1000 on the pod;" >&2
    echo "garcon: with a bind mount, chown -R 1000:1000 the host directory." >&2
    exit 1
fi

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
