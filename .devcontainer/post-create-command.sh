#!/usr/bin/env bash
set -e

git config --global --add safe.directory '*'
aftman install --no-trust-check
selene generate-roblox-std
pnpm install
npm install -g @anthropic-ai/claude-code
npm install -g only-allow
npm install -g @quenty/nevermore-cli
npm run build:sourcemap
