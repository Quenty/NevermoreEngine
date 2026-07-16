# nevermore-claude

Nevermore's [Claude Code](https://code.claude.com/docs/en/overview) plugin. It packages the
Claude Code tooling that Nevermore and its sister repos share, so a single install gives every
project the same skills.

## What it ships

- **`strict-typing-luau` skill** — converts a Luau file from `--!nonstrict` (or untyped) to
  `--!strict`, adding Nevermore's explicit type annotations and fixing every error the checker
  reports. Invoked as `/nevermore-claude:strict-typing-luau`, or automatically when you ask
  Claude to "strictly type" / "add types to" a `.lua`/`.luau` file.

## Install

This monorepo _is_ the marketplace — its catalog is `.claude-plugin/marketplace.json` at the
repo root, and the plugin lives at `tools/nevermore-claude`. You can add it directly:

```shell
/plugin marketplace add Quenty/NevermoreEngine
/plugin install nevermore-claude@nevermore
```

Projects scaffolded with `nevermore init` (games and plugins) ship a `.claude/settings.json`
that registers the marketplace and enables the plugin, so collaborators are prompted to install
it when they trust the repo:

```json
{
  "extraKnownMarketplaces": {
    "nevermore": {
      "source": {
        "source": "github",
        "repo": "Quenty/NevermoreEngine",
        "sparsePaths": [".claude-plugin", "tools/nevermore-claude"]
      }
    }
  },
  "enabledPlugins": { "nevermore-claude@nevermore": true }
}
```

`sparsePaths` limits the marketplace checkout to just the catalog and this plugin instead of
cloning the whole monorepo into the plugin cache.

> **Why the catalog is at the repo root, not next to the plugin.** A marketplace source can
> name a non-root catalog via a `path` field, but on Claude Code 2.1.211 the marketplace
> _refresh/update_ path ignores `path` (it reads `.claude-plugin/marketplace.json` from the
> clone root), so updates break. Keeping the catalog at the root is what makes
> `/plugin marketplace update` work. `sparsePaths` still trims the checkout regardless.

### Local development

To test changes without installing, point Claude Code at this directory:

```shell
claude --plugin-dir ./tools/nevermore-claude
```

Run `/reload-plugins` after edits to pick them up.

## Publishing

There is no separate publish step. The marketplace catalog (`.claude-plugin/marketplace.json` at
the repo root) and the plugin source both live in this repository, so **merging to `main`
publishes the plugin** — users receive it on their next `/plugin marketplace update`.

Versioning rides the repo's existing lerna/Auto release pipeline (conventional commits). When
the package version bumps, the `version` npm lifecycle script runs
`scripts/sync-plugin-version.mjs`, which mirrors that version into
`.claude-plugin/plugin.json` (the field Claude Code reads to detect updates).

## Layout

```
.claude-plugin/marketplace.json  # marketplace catalog at the repo root (source ./tools/nevermore-claude)
tools/nevermore-claude/
  .claude-plugin/plugin.json     # plugin manifest (name, version, description)
  bin/
    nevermore-strict-plan        # whole-package conversion planner; on PATH when the plugin is enabled
  skills/
    strict-typing-luau/          # the skill (SKILL.md, references/, and a maintainer-only evals/ harness)
  scripts/sync-plugin-version.mjs
  package.json                   # private workspace package (version source of truth)
```

The skill's `evals/` directory is a mechanical test harness for maintaining the skill against gold
fixtures in this monorepo; it is not used during conversions and does nothing in a consumer repo.
