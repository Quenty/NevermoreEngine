# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.202.3/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version (use hirsuite or bionic on local arm64/Apple Silicon): hirsute, focal, bionic
ARG VARIANT="hirsute"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

# Install packages
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update

# Install foreman
RUN curl -fsSL https://github.com/Roblox/foreman/releases/download/v1.0.3/foreman-1.0.3-linux.zip -O
RUN unzip foreman-1.0.3-linux.zip
RUN chmod +x ./foreman
RUN mv foreman /usr/local/bin
RUN rm foreman-1.0.3-linux.zip