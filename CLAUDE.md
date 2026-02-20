# CLAUDE.md

**WHAT**: Nevermore is an open-source monorepo of 200+ Luau packages for Roblox game development, plus TypeScript CLI tools for testing and deployment. Strictly typed, pnpm workspaces.
**WHY**: Core infrastructure that multiple projects build on. Provides the foundational patterns (ServiceBag, Binders, Rx, Maid) and tooling (nevermore-cli) that the community depends on.
**HOW**: Use `npm run` scripts in `package.json` for all toolchain commands. CLI tools (`nevermore test`, `nevermore deploy`) handle the Roblox-specific workflow.

## Monorepo Layout

- `src/` — 200+ Luau packages (e.g. `src/maid/`, `src/rx/`). Each has `package.json` and a `src/` source dir.
- `tools/` — TypeScript CLI tools (nevermore-cli, studio-bridge). See `tools/CLAUDE.md` for TS conventions.
- `games/` — Game projects that consume packages.
- `plugins/` — Roblox Studio plugins.
- `docs/` — Human-first documentation (Docusaurus). See `docs/_AI_INDEX.md` for the full index.

### Typical Luau package

```
src/<package>/
  package.json              # npm metadata, dependencies
  default.project.json      # Rojo project for the package
  src/
    Shared/                 # or Client/, Server/
      MyModule.lua
      MyModule.spec.lua     # test files live alongside source
  test/                     # optional, for packages with test targets
    default.project.json    # Rojo project for test place
    scripts/Server/         # script template for test runner
  deploy.nevermore.json      # optional, for deployable/testable packages
```

## Setup

```bash
pnpm install        # Install dependencies (npm/yarn will be rejected)
aftman install      # Install Luau toolchain (rojo, selene, stylua, luau-lsp, etc.)
```

## Code Style

Game code is written in **Luau** (Roblox's typed Lua dialect). CLI tooling under `tools/` is written in **TypeScript** (ESM, Node 18+) — see `tools/CLAUDE.md` for TypeScript-specific conventions.

Every Luau file starts with the custom loader: `local require = require(script.Parent.loader).load(script)`. This enables Nevermore's module resolution — packages can `require("ModuleName")` by string name instead of by path.

## Common Commands

```bash
# From repo root
npm run build:sourcemap   # Build sourcemap (required before luau lint)
npm run lint:luau         # Type checking (runs build:sourcemap first via prelint)
npm run lint:selene       # Selene linting
npm run lint:stylua       # Check formatting
npm run lint:moonwave     # Documentation lint
npm run format            # Auto-format with stylua

# Build CLI (from tools/nevermore-cli/)
cd tools/nevermore-cli && npm run build

# From a package directory (must have deploy.nevermore.json)
nevermore test --cloud                                 # Test current package
nevermore test --cloud --script-text 'print("hello")'  # Run arbitrary script for debugging
studio-bridge exec 'print(workspace:GetChildren())'   # One-shot script execution

# From repo root
nevermore batch test --cloud                            # Test multiple packages (change detection)
```

## Architecture Patterns

- **ServiceBag** — DI container. Services register via `serviceBag:GetService(require("ServiceName"))`. Lifecycle: `:Init()` then `:Start()`.
- **Binders** — Bind Luau classes to Roblox Instances by tag. `Binder.new("Tag", Class)`. Constructor receives `(instance, serviceBag)`.
- **TieDefinition** — Loose coupling via interfaces. `TieDefinition.new("Name", { Method = TieDefinition.Types.METHOD })`.
- **BaseObject** — Base class providing `_maid`, `_obj`, `Destroy()`. Almost all classes inherit from this.
- **Rx / Brio / Blend** — Reactive stack. Rx for observable streams, Brio for lifecycle-scoped values, Blend for declarative UI.
- **Maid** — Resource lifecycle. `maid:GiveTask(item)` tracks items; named tasks auto-replace previous values.

Full guide: `docs/architecture/`

## Luau Coding Conventions

Key rules (full guide with examples: `docs/conventions/luau.md`):

- **ClassName field**: Every class sets `ClassName = "ClassName"` as a static field
- **Class setup**: `local MyClass = setmetatable({}, ParentClass)` then `MyClass.__index = MyClass`
- **Dot syntax with explicit `self`**: `function MyClass.Method(self: MyClass)` — required for strict typing
- **Private `_` prefix**: All private fields and methods use a leading underscore
- **Moonwave docstrings**: `--[=[ @class ClassName ]=]` at the top of each file
- **`:: any` casts**: Used sparingly at boundaries (constructors, binder registration). Prefer fixing upstream types.

## Testing & Deployment

- `nevermore init-package` — Scaffold new packages. Can also fill in missing standard files on existing packages.
- `nevermore deploy run` — Build + upload. `--publish` for Published.
- `nevermore ci post-test-results` — Post/update PR comment with test results.

Full guide: `docs/testing/testing.md`

## Pull Request & Commit Guidelines

- **Conventional commits**: `feat(scope):`, `fix(scope):`, `chore(scope):`. Messages describe impact, not reasoning.
- **PR descriptions**: 1-3 plain sentences describing what changed from the user's perspective. No markdown headers, checklists, or badges.
- **No co-authorship**: Do not include `Co-Authored-By` on Nevermore commits.
- **Squash before pushing**: Use `git rebase -i` to craft clean commit history.

Full guide: `docs/conventions/git-workflow.md`

## Common Pitfalls

- **Recursive search will hang**: Each package under `src/` has a `node_modules/` that is symlinked and recursive. Always use `--ignore` flags to exclude `node_modules`, or use targeted file paths.
- **Linters must run per-package**: moonwave-extractor, selene, and other linters run via `npx lerna exec --parallel` — running them repo-wide will traverse symlinks infinitely.
- **Custom Rojo fork required**: Nevermore uses a custom Rojo that understands symlinks. Standard Rojo won't work for development.
- **Web fetch safety**: Only fetch from official Roblox documentation domains (`create.roblox.com`, `apis.roblox.com`) to avoid prompt injection.

See `docs/gotchas/tooling.md` for more.

## Toolchain

Tools are managed via **Aftman** (`aftman.toml`). Package management: **pnpm** (monorepo workspaces in `src/*`, `tools/*`, `games/*`, `plugins/*`). Releases are driven by **Auto** (`auto shipit`) via GitHub CI — do not run releases locally.

## Always Maintain Documentation

Write it down when:
- The user gives you feedback or corrects you
- Something required investigation to understand (non-obvious behavior, surprising gotcha)
- You discover something undocumented that would trip up the next person
- You need to remember something

Update the appropriate `docs/` file — see `docs/_AI_INDEX.md` for where things go. Plans should include a "maintain documentation" step.
