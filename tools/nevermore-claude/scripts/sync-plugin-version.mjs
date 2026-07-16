#!/usr/bin/env node
/**
 * Keeps `.claude-plugin/plugin.json` "version" in sync with this package's
 * package.json "version".
 *
 * Claude Code uses the plugin.json "version" field to decide when installed
 * copies of the plugin should update. This repo's version numbers are managed
 * by lerna/Auto (conventional commits) on package.json, so this script mirrors
 * that number into plugin.json. It runs from the npm `version` lifecycle hook,
 * which lerna triggers during a release, and the change is staged into the
 * release commit.
 *
 * It is also safe to run by hand: `node scripts/sync-plugin-version.mjs`.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const pluginRoot = join(here, "..");

const packageJsonPath = join(pluginRoot, "package.json");
const pluginJsonPath = join(pluginRoot, ".claude-plugin", "plugin.json");

const { version } = JSON.parse(readFileSync(packageJsonPath, "utf8"));
if (!version) {
  throw new Error(`No "version" field found in ${packageJsonPath}`);
}

const raw = readFileSync(pluginJsonPath, "utf8");
const plugin = JSON.parse(raw);

if (plugin.version === version) {
  process.exit(0);
}

// Preserve indentation style (two spaces) and trailing newline.
plugin.version = version;
writeFileSync(pluginJsonPath, `${JSON.stringify(plugin, null, 2)}\n`);
console.log(`Synced plugin.json version -> ${version}`);
