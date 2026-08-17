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

## Building

Versions are pinned as `ARG`s at the top of the `Dockerfile` - Renovate bumps
them, CI rebuilds and pushes on merge to `main`.

```bash
just build   # clone upstream at the pinned tag, build base + wrapper
just push
just run     # local run with state in ./data
```

## Licence

Garcon is GPL-3.0 (© Alex Lau). This repo redistributes it in image form and is
licensed the same way.
