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
| How one package works inside, and why | `src/<package>/docs/` — see below |
| Ambiguous case not covered above | Resolve it, then add a row to this table |

### Package docs

`docs/` here is for **consumers** of Nevermore. A package may also carry its own
`src/<package>/docs/`, linked from its `README.md` under "Working on this package".

Package docs are for **design intent and design decisions that cannot live in code**: why an
implementation is shaped the way it is, what was tried and rejected and why, the outside behavior
it is built around. They answer "why is this like this" for the person who changes it next.

They are **public documents** — they live in a public repo and ship inside the published npm
package. A different reader, not a lower standard.

Two rules:

- **Same quality bar as these docs.** Written for a person, context before rules, edited, kept
  true as the code changes. A package doc that has gone stale is worse than no package doc.
- **Used sparingly.** These are not scratch notes, a changelog, or a place to restate what the
  code already says. If the knowledge fits in a comment beside the code, it goes there instead.
  Prefer improving an existing page over adding another. Most packages should have none.

Split by audience, not topic: if a game developer using the package would act on it, it belongs in
`docs/`; if only someone changing that package would, it belongs in the package. When a
consumer-facing page has a matching package doc, link to it so readers can find the "why".

`src/clienttranslator/docs/` is the reference example
([design.md](../src/clienttranslator/docs/design.md),
[engine-behavior.md](../src/clienttranslator/docs/engine-behavior.md)).

## Index

| Doc | Description |
|-----|-------------|
| [intro.md](intro.md) | Getting started with Nevermore, why use it, key packages |
| [install.md](install.md) | Installation methods: NPM + CLI, existing Rojo projects, plugins |
| [cli.md](cli.md) | `nevermore` CLI command reference: every command and flag (`init`, `install`, `login`, `test`, `deploy`, `batch`, `tools`), global options, command tree |
| [deploy.md](deploy.md) | `nevermore deploy`: login, `deploy init`, `deploy run`, config schema, flag reference, common workflows |
| [architecture/](architecture/index.md) | Architecture: workspace layout, design philosophy, ServiceBag, dependency injection |
| [architecture/patterns.md](architecture/patterns.md) | Core patterns: Maid, BaseObject, Binder, Rx, Brio, Blend, AdorneeData, TieDefinition; Brio pipeline pitfalls |
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
| [gotchas/localization.md](gotchas/localization.md) | Localization gotchas **for consumers**: which locale file a player gets (script vs region), missing-key behavior, runtime-generated keys belonging to the realm that generated them, self-correcting text, one entry per key. Design intent lives in `src/clienttranslator/docs/` |
