---
title: Architecture
sidebar_position: 3
---

# Architecture

Nevermore's architecture is built around a few core ideas: services as singletons managed by a dependency injection container, and composable packages that can be combined without knowing about each other.

## Workspace Layout

The monorepo is organized into four workspace areas:

| Directory | Contents | Language |
|-----------|----------|----------|
| `src/` | 200+ Luau packages (e.g. `src/maid/`, `src/rx/`, `src/servicebag/`). Each is an independently versioned npm package with its own `package.json`. This is where most development happens. | Luau |
| `tools/` | CLI tools: `nevermore-cli` (test, deploy, scaffolding), `studio-bridge` (WebSocket bridge to Studio), and shared helper libraries. | TypeScript |
| `games/` | Game projects used for integration testing. Each game has a Rojo project, deploy config, and entry scripts that consume packages from `src/`. | Luau |
| `plugins/` | Roblox Studio plugins. Same structure as games but targeting the plugin context. | Luau |

`docs/` contains the Docusaurus documentation site (what you're reading now).

## Guides

- **[Design Principles](design.md)** — Why Nevermore is structured as a mono-repo of composable packages, what types of packages exist, and what the project optimizes for.
- **[Using Services](servicebag.md)** — How ServiceBag provides dependency injection and lifecycle management. The most important architectural concept to understand.
- **[Core Patterns](patterns.md)** — Maid, BaseObject, Binder, Rx, Brio, Blend, AdorneeData, and TieDefinition — the building blocks that appear throughout the codebase.
