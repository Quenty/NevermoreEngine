## Nevermore Template Helpers

Shared utilities for scaffolding, building, and template substitution across Nevermore CLI tools.

### Modules

| Module | Purpose |
|--------|---------|
| `scaffolding/` | `TemplateHelper` — directory template creation with Handlebars |
| `build/` | `BuildContext` + `rojoBuildAsync` — sole rojo invocation point for the entire codebase |
| `substitution/` | `substituteTemplate` — Handlebars-based `{{VAR}}` replacement with `noEscape` |

### Build API

```typescript
import { BuildContext, rojoBuildAsync } from '@quenty/nevermore-template-helpers';

// Temp directory (auto-cleaned)
const ctx = await BuildContext.createAsync({ mode: 'temp', prefix: 'my-build-' });
const projectPath = await ctx.writeProjectAsync('default.project.json', {
  name: 'MyProject',
  tree: { $className: 'DataModel' },
});
await rojoBuildAsync({ projectPath, output: path.join(ctx.dir, 'output.rbxl') });
await ctx.cleanupAsync();

// Persistent directory (survives across runs)
const ctx2 = await BuildContext.createAsync({ mode: 'persistent', buildDir: './build' });
```

### Template Substitution

```typescript
import { substituteTemplate } from '@quenty/nevermore-template-helpers';

const result = substituteTemplate('local PORT = "{{PORT}}"', { PORT: '8080' });
// → 'local PORT = "8080"'
```

Uses Handlebars with `noEscape: true` so Lua source code (`&`, `<`, etc.) is not HTML-escaped.
