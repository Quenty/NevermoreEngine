# syntax=docker/dockerfile:1
FROM ubuntu:24.04
ARG STUDIO_VERSION
ARG DEBIAN_FRONTEND=noninteractive

# --- System deps (cached layer, rarely changes) ---
# Mirrors linux-prerequisites.ts:installDependenciesAsync()
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg software-properties-common \
        xvfb openbox mesa-utils \
        gcc-mingw-w64-x86-64 unzip procps \
    # WineHQ repo for Wine 11+ (same logic as linux-prerequisites.ts:91-128)
    && mkdir -pm755 /etc/apt/keyrings \
    && curl -sL https://dl.winehq.org/wine-builds/winehq.key \
        -o /etc/apt/keyrings/winehq-archive.key \
    && curl -sfL https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
        -o /etc/apt/sources.list.d/winehq-noble.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends winehq-stable \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Node.js 22 LTS ---
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && corepack enable pnpm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Non-root user ---
RUN useradd -m -s /bin/bash studio
USER studio
WORKDIR /home/studio

# --- Build studio-bridge from source (via named build context "workspace") ---
COPY --from=workspace --chown=studio:studio package.json pnpm-workspace.yaml pnpm-lock.yaml tsconfig.json /home/studio/build/
COPY --from=workspace --chown=studio:studio tools/ /home/studio/build/tools/
WORKDIR /home/studio/build
RUN pnpm install --frozen-lockfile --filter "@quenty/studio-bridge..." \
    && pnpm -r --filter "@quenty/studio-bridge..." run build

# --- Run studio-bridge to set up Studio (single source of truth!) ---
# Invoke cli.js directly — workspace deps are resolved by pnpm in node_modules.
RUN node tools/studio-bridge/dist/src/cli/cli.js linux setup \
    ${STUDIO_VERSION:+--studio-version "$STUDIO_VERSION"}

# --- Install studio-bridge globally for runtime, then clean up ---
# Use pnpm deploy to create a self-contained copy with resolved workspace deps,
# then link the binary. This avoids npm registry lookups for workspace packages.
RUN pnpm --filter "@quenty/studio-bridge" deploy --legacy --prod /home/studio/.studio-bridge \
    && mkdir -p /home/studio/.npm-global/bin \
    && ln -s /home/studio/.studio-bridge/dist/src/cli/cli.js /home/studio/.npm-global/bin/studio-bridge \
    && chmod +x /home/studio/.studio-bridge/dist/src/cli/cli.js \
    && rm -rf /home/studio/build

# --- Environment (matches linux-wine-env.ts:buildWineEnv) ---
ENV STUDIO_DIR=/home/studio/roblox-studio \
    WINEPREFIX=/home/studio/.wine \
    DISPLAY=:99 \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEDLLOVERRIDES="mscoree=d;mshtml=d" \
    MESA_GL_VERSION_OVERRIDE=4.5 \
    MESA_GLSL_VERSION_OVERRIDE=450 \
    NPM_CONFIG_PREFIX=/home/studio/.npm-global \
    PATH=/home/studio/.npm-global/bin:$PATH

COPY --chown=studio:studio entrypoint.sh /home/studio/entrypoint.sh
RUN chmod +x /home/studio/entrypoint.sh
WORKDIR /home/studio
ENTRYPOINT ["/home/studio/entrypoint.sh"]
CMD ["bash"]
