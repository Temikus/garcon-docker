# garcon-docker

[![build](https://github.com/temikus/garcon-docker/actions/workflows/build.yml/badge.svg)](https://github.com/temikus/garcon-docker/actions/workflows/build.yml)
[![license](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

Container images for [cfal/garcon](https://github.com/cfal/garcon), a self-hosted
browser workspace for coding agents. Upstream ships a `Dockerfile` but publishes
no image, so this repo builds one and pushes it to
`ghcr.io/temikus/garcon`.

## What this adds on top of upstream

- **Published image.** Built from the upstream tree at a pinned tag, with `bun`
  pinned rather than `latest`.
- **`gh` CLI.** Garcon hides its Pull Requests tab unless `gh` is on the host;
  upstream's image doesn't include it.
- **One volume for all state.** Upstream's `docker-compose.yml` bind-mounts six
  separate host paths. Here everything lands under `/data`, which makes it a
  single PVC in Kubernetes.
- **Runs unprivileged.** Upstream's image runs as root. This one runs as
  `garcon`, uid/gid 1000. See [Running as non-root](#running-as-non-root).

Agents come from upstream and are already on `$PATH`: `claude`, `codex`,
`opencode`, and `amp`.

## Usage

```bash
docker run -d --init \
  -p 8080:8080 \
  -v garcon-data:/data \
  ghcr.io/temikus/garcon:0.3.3
```

Open `http://127.0.0.1:8080` and create an account at `/setup`. Agents are
logged in from inside the container (`docker exec -it <id> claude`,
`codex login`, `gh auth login`, and so on) - those credentials persist on the
volume.

Clone the repos you want to work on into `/data/projects`.

### Layout under `/data`

| Path                 | Contents                          |
| -------------------- | --------------------------------- |
| `/data/.garcon`      | Garcon config, chats, workspaces  |
| `/data/projects`     | Project checkouts (`GARCON_PROJECT_BASE_DIR`) |
| `/data/.claude`      | Claude Code credentials/config    |
| `/data/.codex`       | Codex                             |
| `/data/.opencode`    | OpenCode config                   |
| `/data/opencode-*`   | OpenCode data/state/cache         |
| `/data/.amp`         | Amp                               |
| `/data/.config`      | `gh`, `git`, everything else XDG  |

The entrypoint creates these and symlinks the ones without an env var override
into `$HOME`.

## Running as non-root

The container runs as `garcon`, uid/gid 1000, and needs `/data` writable by that
uid. On Kubernetes, set `fsGroup` so the kubelet fixes up the volume at mount
time:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

With a bind mount, `chown -R 1000:1000` the host directory first. Named Docker
volumes and `docker run -v garcon-data:/data` need nothing - they inherit
ownership from the image.

If `/data` isn't writable the entrypoint exits immediately and says so rather
than failing deeper in.

> **Upgrading from an image that ran as root:** state written by the old root
> container is not readable by uid 1000. Adding `fsGroup: 1000` as above fixes
> an existing PVC in place on the next mount; otherwise recreate the volume and
> re-authenticate the agents.

## Building

Versions are pinned as `ARG`s at the top of the `Dockerfile` - Renovate bumps
them, CI rebuilds and pushes on merge to `main`.

```bash
just build   # clone upstream at the pinned tag, build base + wrapper
just check   # lint + smoke-test the built image
just push
just run     # local run with state in ./data
```

`just test` boots the built image and asserts it comes up as uid 1000, that
every agent binary resolves and reports a version, that `/` returns 200, and
that `/data` is writable. CI runs it before pushing.

## Licence

Garcon is GPL-3.0 (© Alex Lau). This repo redistributes it in image form and is
licensed the same way.
