image := "ghcr.io/temikus/garcon"
upstream_dir := ".upstream"

garcon_version := `sed -n 's/^ARG GARCON_VERSION=//p' Dockerfile | head -1`
bun_tag := `sed -n 's/^ARG BUN_TAG=//p' Dockerfile | head -1`
build_date := `date -u +%Y-%m-%dT%H:%M:%SZ`
vcs_ref := `git rev-parse --short HEAD 2>/dev/null || echo unknown`

default:
    @just --list

# Print the pinned upstream garcon version
version:
    @echo {{ garcon_version }}

# Clone the upstream garcon source at the pinned tag
fetch:
    rm -rf {{ upstream_dir }}
    git clone --depth 1 --branch v{{ garcon_version }} \
        https://github.com/cfal/garcon.git {{ upstream_dir }}

# Build the upstream base image, then layer this repo's wrapper on top
build: fetch
    docker build \
        --platform=linux/amd64 \
        --build-arg BUN_TAG={{ bun_tag }} \
        -t garcon-upstream:local \
        {{ upstream_dir }}
    docker build \
        --platform=linux/amd64 \
        --build-arg GARCON_BASE_IMAGE=garcon-upstream:local \
        --build-arg GARCON_VERSION={{ garcon_version }} \
        --build-arg BUILD_DATE={{ build_date }} \
        --build-arg VCS_REF={{ vcs_ref }} \
        -t {{ image }}:{{ garcon_version }} \
        .

# Push the built image
push:
    docker push {{ image }}:{{ garcon_version }}

# Run locally on http://127.0.0.1:8080 with state in ./data
run:
    mkdir -p data
    docker run --rm -it --init \
        -p 8080:8080 \
        -v {{ justfile_directory() }}/data:/data \
        {{ image }}:{{ garcon_version }}

# Remove the upstream checkout
clean:
    rm -rf {{ upstream_dir }}
