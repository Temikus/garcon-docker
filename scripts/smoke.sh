#!/usr/bin/env bash
# Boot the built image and assert it runs unprivileged with a working agent
# toolchain. Real container, real HTTP, real git.
#
# Usage: scripts/smoke.sh <image>
set -euo pipefail

IMAGE="${1:?usage: smoke.sh <image>}"
PORT="${SMOKE_PORT:-18080}"
NAME="garcon-smoke-$$"
# A named volume inherits /data's ownership from the image, which is the path
# the README tells people to use. A bind mount would arrive owned by whoever
# ran this and trip the entrypoint's own guard - see the negative test below.
VOLUME="garcon-smoke-$$"
DATA="$(mktemp -d)"

failures=0

cleanup() {
    docker rm -f "${NAME}" >/dev/null 2>&1 || true
    docker volume rm "${VOLUME}" >/dev/null 2>&1 || true
    rm -rf "${DATA}"
}
trap cleanup EXIT

check() {
    local what="$1" want="$2" got="$3"
    if [ "${got}" = "${want}" ]; then
        printf 'ok   %-34s %s\n' "${what}" "${got}"
    else
        printf 'FAIL %-34s want %q, got %q\n' "${what}" "${want}" "${got}"
        failures=$((failures + 1))
    fi
}

echo "== booting ${IMAGE} =="
docker run -d --init --name "${NAME}" \
    -p "${PORT}:8080" \
    -v "${VOLUME}:/data" \
    "${IMAGE}" >/dev/null

# The server logs this line once it is accepting connections.
for _ in $(seq 1 60); do
    if docker logs "${NAME}" 2>&1 | grep -q '\[server\] Started at'; then
        break
    fi
    if [ -z "$(docker ps -q -f "name=${NAME}")" ]; then
        echo "FAIL container exited during startup:"
        docker logs "${NAME}" 2>&1 | tail -20
        exit 1
    fi
    sleep 1
done

echo
echo "== identity =="
check "uid" "1000" "$(docker exec "${NAME}" id -u)"
check "gid" "1000" "$(docker exec "${NAME}" id -g)"
check "username" "garcon" "$(docker exec "${NAME}" id -un)"

echo
echo "== agents on PATH =="
for bin in claude codex opencode amp gh git; do
    path="$(docker exec "${NAME}" sh -c "command -v ${bin} || true")"
    if [ -z "${path}" ]; then
        printf 'FAIL %-34s not on PATH\n' "${bin}"
        failures=$((failures + 1))
        continue
    fi
    if version="$(docker exec "${NAME}" sh -c "${bin} --version 2>&1 | head -1")" \
        && [ -n "${version}" ]; then
        printf 'ok   %-34s %s\n' "${bin}" "${version}"
    else
        printf 'FAIL %-34s on PATH at %s but --version failed\n' "${bin}" "${path}"
        failures=$((failures + 1))
    fi
done

echo
echo "== http =="
check "GET / status" "200" \
    "$(curl -fsS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/" || echo failed)"

echo
echo "== writable state =="
check "git in /data/projects" "ok" "$(docker exec "${NAME}" sh -c '
    cd /data/projects \
    && git init -q smoke \
    && cd smoke \
    && git -c user.email=smoke@test -c user.name=smoke commit -q --allow-empty -m smoke \
    && echo ok' 2>&1 | tail -1)"

# Ownership of the dirs the entrypoint creates, and of the two symlink targets
# that have no env-var override.
for path in /data/.garcon /data/projects /data/.amp /data/.config; do
    check "owner of ${path}" "garcon garcon" \
        "$(docker exec "${NAME}" stat -c '%U %G' "${path}")"
done

for link in .amp .config; do
    check "\$HOME/${link} is a symlink" "symbolic link" \
        "$(docker exec "${NAME}" stat -c '%F' "/home/garcon/${link}")"
done

echo
echo "== unwritable /data is rejected =="
# Read-only so this holds regardless of how the host maps bind-mount ownership.
guard_output="$(docker run --rm -v "${DATA}:/data:ro" "${IMAGE}" 2>&1 || true)"
case "${guard_output}" in
    *"is not writable by garcon"*)
        printf 'ok   %-34s %s\n' "guard message" "present" ;;
    *)
        printf 'FAIL %-34s got %q\n' "guard message" "${guard_output}"
        failures=$((failures + 1)) ;;
esac

if docker run --rm -v "${DATA}:/data:ro" "${IMAGE}" >/dev/null 2>&1; then
    printf 'FAIL %-34s exited 0, expected non-zero\n' "guard exit status"
    failures=$((failures + 1))
else
    printf 'ok   %-34s %s\n' "guard exit status" "non-zero"
fi

echo
if [ "${failures}" -ne 0 ]; then
    echo "${failures} check(s) failed"
    exit 1
fi
echo "all checks passed"
