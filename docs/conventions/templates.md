---
title: Template Conventions
sidebar_position: 4
---

# Template Conventions

Generated and templated files (Luau scripts, Rojo projects, etc.) follow a consistent layout across CLI tools.

## Directory layout

All template files live in a `templates/` directory at the root of the tool package that owns them:

```
tools/nevermore-cli/templates/
  batch-test-runner.luau          # Batch test execution script
  game-template/                  # Game scaffolding
  nevermore-library-package-template/  # Package scaffolding
  nevermore-service-package-template/  # Service package scaffolding
  plugin-template/                # Plugin scaffolding

tools/studio-bridge/templates/    # Studio bridge plugin template
```

## Placeholder pattern

Templates use `{{PLACEHOLDER}}` syntax for values filled in at runtime. The double-brace pattern is distinct from Lua/Luau syntax, making placeholders easy to find and unlikely to collide with real code.

Example from `batch-test-runner.luau`:
```lua
local packageSlugs = {{PACKAGE_SLUGS}}
```

Replaced at runtime with:
```lua
local packageSlugs = { "maid", "blend", "roguehumanoid" }
```

## Resolving template paths

Use `resolveTemplatePath` from `@quenty/nevermore-template-helpers` to resolve template paths at runtime. It finds the calling package's root (via `package.json`) and appends `templates/<name>`:

```typescript
import { resolveTemplatePath } from '@quenty/nevermore-template-helpers';

const templatePath = resolveTemplatePath(import.meta.url, 'batch-test-runner.luau');
```

This works regardless of where the compiled JS ends up relative to the source.
