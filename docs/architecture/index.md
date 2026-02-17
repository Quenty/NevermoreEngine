---
title: Architecture
sidebar_position: 3
---

# Architecture

Nevermore's architecture is built around a few core ideas: services as singletons managed by a dependency injection container, and composable packages that can be combined without knowing about each other.

- **[Design Principles](design.md)** — Why Nevermore is structured as a mono-repo of composable packages, what types of packages exist, and what the project optimizes for.
- **[Using Services](servicebag.md)** — How ServiceBag provides dependency injection and lifecycle management. The most important architectural concept to understand.
