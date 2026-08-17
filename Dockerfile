# Wrapper around the upstream cfal/garcon image.
#
# Upstream ships a Dockerfile but no published image, so CI (and `just build`)
# builds the upstream tree at GARCON_VERSION first, tags it locally, then layers
# this file on top. See README.md.

# renovate: datasource=github-releases depName=cfal/garcon extractVersion=^v(?<version>.*)$
ARG GARCON_VERSION=0.3.3
# renovate: datasource=docker depName=oven/bun
ARG BUN_TAG=1.3.14
ARG GARCON_BASE_IMAGE=garcon-upstream:local

FROM ${GARCON_BASE_IMAGE}

ARG GARCON_VERSION
ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="temikus" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.title="garcon" \
    org.opencontainers.image.description="Garcon - self-hosted browser workspace for coding agents" \
    org.opencontainers.image.version=$GARCON_VERSION \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.source="https://github.com/temikus/garcon-docker" \
    org.opencontainers.image.url="https://github.com/cfal/garcon" \
    org.opencontainers.image.licenses="GPL-3.0-only"

# gh unlocks garcon's Pull Requests tab; upstream leaves it out of the image.
# renovate: datasource=github-releases depName=cli/cli extractVersion=^v(?<version>.*)$
ARG GH_VERSION=2.97.0
RUN curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
        -o /tmp/gh.tar.gz \
    && tar -xzf /tmp/gh.tar.gz -C /tmp \
    && install -m0755 "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
    && rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_amd64"

# mise - version manager for tools (node, python, go, etc.)
# renovate: datasource=github-releases depName=jdx/mise extractVersion=^v(?<version>.*)$
ARG MISE_VERSION=2026.8.6
RUN curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64.tar.gz" \
        -o /tmp/mise.tar.gz \
    && tar -xzf /tmp/mise.tar.gz -C /tmp \
    && install -m0755 /tmp/mise /usr/local/bin/mise \
    && rm -rf /tmp/mise.tar.gz /tmp/mise
ENV MISE_DATA_DIR=/data/.mise
ENV MISE_CONFIG_DIR=/data/.mise
ENV PATH="${MISE_DATA_DIR}/shims:${PATH}"

# Everything stateful lives under a single mounted volume so one PVC is enough.
# The paths that garcon/agents expose as env vars are pointed at it directly;
# the rest are symlinked in by the entrypoint.
ENV GARCON_DATA_DIR=/data \
    GARCON_CONFIG_DIR=/data/.garcon \
    GARCON_PROJECT_BASE_DIR=/data/projects \
    CLAUDE_CONFIG_DIR=/data/.claude \
    CODEX_HOME=/data/.codex \
    OPENCODE_CONFIG_DIR=/data/.opencode

COPY entrypoint.sh /usr/local/bin/garcon-entrypoint.sh
RUN chmod 0755 /usr/local/bin/garcon-entrypoint.sh

# Upstream sets HOME=/home/garcon but never creates the user, so the image runs
# as root. The bun base already holds uid/gid 1000; renaming it is the only way
# to land on 1000 (useradd --uid 1000 would collide).
RUN usermod --login garcon --home /home/garcon bun \
    && groupmod --new-name garcon bun \
    && mkdir -p /data /data/.mise \
    && chown -R garcon:garcon /home/garcon /data

VOLUME ["/data"]

USER garcon

ENTRYPOINT ["/usr/local/bin/garcon-entrypoint.sh"]
CMD ["bun", "server/main.ts"]
