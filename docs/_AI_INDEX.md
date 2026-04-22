# Documentation

This file is an index for AI agents. The `_` prefix keeps it out of Docusaurus. The docs themselves are human-first guides — written for developers, readable by AI as reference.

## Principles

- **Docs are for humans**: Write as guides (context → explanation → example), not rule lists. AI reads them too, but humans come first.
- **CLAUDE.md is stable**: Edit rarely. New knowledge goes to docs/.
- **Gotchas are for everyone**: `gotchas/` captures things that trip up humans and AI agents alike.
- **Graduation**: When a gotchas.md section grows to 10+ items, promote it to its own doc and update this index.
- **Always update the index**: When adding or changing a doc, update this index.
- **Self-reinforcing**: If you encounter a documentation decision not covered here, resolve it and add the resolution as a new principle.

### When updating documentation

1. Find the right doc (use quick reference below)
2. Write human-first (context before rules, annotated examples)
3. Add Docusaurus frontmatter (`title`, `sidebar_position`) to new docs
4. Update this index if you created or renamed a doc
5. **Check**: Does the quick reference cover this case? If not, add a row.
6. **Check**: Did anything you read feel outdated or misplaced? Fix it now.

### Quick reference: where does new knowledge go?

| Situation | Action |
|-----------|--------|
| Small gotcha or tip | Append to the relevant file in `gotchas/` |
| New convention or pattern | Update the relevant existing doc |
| Entirely new topic area | Create a new doc + add to Index below |
| Universal rule for every session | Update CLAUDE.md (rare) |
| A gotchas section has 10+ items | Graduate it to its own doc |
| Ambiguous case not covered above | Resolve it, then add a row to this table |

## Index

| Doc | Description |
|-----|-------------|
| [intro.md](intro.md) | Getting started with Nevermore, why use it, key packages |
| [install.md](install.md) | Installation methods: NPM + CLI, existing Rojo projects, plugins |
| [architecture/](architecture/index.md) | Architecture: workspace layout, design philosophy, ServiceBag, dependency injection |
| [architecture/patterns.md](architecture/patterns.md) | Core patterns: Maid, BaseObject, Binder, Rx, Brio, Blend, AdorneeData, TieDefinition |
| [build.md](build.md) | Contributing: local setup, tools, versioning, custom Rojo |
| [testing/](testing/index.md) | Testing: Jest3, deploy config, CLI commands, credentials, CI |
| [testing/integration-testing.md](testing/integration-testing.md) | Integration testing: full-game tests, base place merging, deploy pipeline |
| [conventions/luau.md](conventions/luau.md) | Strict typing patterns, class structure, common type imports |
| [conventions/typescript.md](conventions/typescript.md) | CLI tool conventions: naming, commands, error handling, dryrun |
| [conventions/git-workflow.md](conventions/git-workflow.md) | Git conventions: conventional commits, interactive rebase, branching |
| [conventions/templates.md](conventions/templates.md) | Template conventions: directory layout, placeholder pattern, path resolution |
| [ides/vscode.md](ides/vscode.md) | VSCode/Cursor setup: extensions, luau-lsp config, settings |
| [gotchas/tooling.md](gotchas/tooling.md) | Tooling gotchas: Lune, symlinks, Rojo, linter CLI tools, CI annotations |
| [gotchas/troubleshooting.md](gotchas/troubleshooting.md) | Troubleshooting: setup failures, linting issues, test auth, Rojo errors |
