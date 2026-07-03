FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG AFTMAN_VERSION=0.3.0

RUN curl -fsSL "https://github.com/LPGhatguy/aftman/releases/download/v${AFTMAN_VERSION}/aftman-${AFTMAN_VERSION}-linux-x86_64.zip" -o /tmp/aftman.zip \
    && unzip /tmp/aftman.zip -d /tmp/aftman \
    && chmod +x /tmp/aftman/aftman \
    && mv /tmp/aftman/aftman /usr/local/bin/aftman \
    && rm -rf /tmp/aftman /tmp/aftman.zip

USER vscode
RUN aftman self-install
