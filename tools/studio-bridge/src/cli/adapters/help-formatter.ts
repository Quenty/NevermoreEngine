/**
 * Custom help formatter that groups commands into "Execution" and
 * "Infrastructure" categories, matching the target CLI layout.
 */

import type { CommandRegistry } from '../../commands/framework/command-registry.js';

// ---------------------------------------------------------------------------
// Group descriptions for help display
// ---------------------------------------------------------------------------

const GROUP_DESCRIPTIONS: Record<string, string> = {
  console: 'Execute code and view logs',
  explorer: 'Query and modify the DataModel',
  properties: 'Read and write instance properties',
  viewport: 'Screenshots and camera control',
  data: 'Load and save serialized data',
  playtest: 'Control play test sessions',
  process: 'Manage Studio processes',
  plugin: 'Manage the bridge plugin',
  action: 'Invoke a Studio action',
};

// ---------------------------------------------------------------------------
// Formatter
// ---------------------------------------------------------------------------

/**
 * Format a categorized help string from the command registry.
 * Groups are listed under their category with aligned descriptions.
 */
export function formatGroupedHelp(registry: CommandRegistry): string {
  const lines: string[] = [];

  lines.push('studio-bridge <command> [options]');
  lines.push('');

  // Collect unique groups per category
  const executionGroups = new Set<string>();
  const infrastructureGroups = new Set<string>();
  const executionTopLevel: Array<{ name: string; description: string }> = [];
  const infrastructureTopLevel: Array<{ name: string; description: string }> = [];

  for (const cmd of registry.getAll()) {
    if (cmd.group !== null) {
      if (cmd.category === 'execution') {
        executionGroups.add(cmd.group);
      } else {
        infrastructureGroups.add(cmd.group);
      }
    } else {
      const entry = { name: cmd.name, description: cmd.description };
      if (cmd.category === 'execution') {
        executionTopLevel.push(entry);
      } else {
        infrastructureTopLevel.push(entry);
      }
    }
  }

  // Execution section
  if (executionGroups.size > 0 || executionTopLevel.length > 0) {
    lines.push('Execution:');
    for (const group of executionGroups) {
      const desc = GROUP_DESCRIPTIONS[group] ?? '';
      lines.push(formatLine(`${group} <command>`, desc));
    }
    for (const cmd of executionTopLevel) {
      lines.push(formatLine(cmd.name, cmd.description));
    }
    lines.push('');
  }

  // Infrastructure section
  if (infrastructureGroups.size > 0 || infrastructureTopLevel.length > 0) {
    lines.push('Infrastructure:');
    for (const group of infrastructureGroups) {
      const desc = GROUP_DESCRIPTIONS[group] ?? '';
      lines.push(formatLine(`${group} <command>`, desc));
    }
    for (const cmd of infrastructureTopLevel) {
      lines.push(formatLine(cmd.name, cmd.description));
    }
    lines.push('');
  }

  return lines.join('\n');
}

function formatLine(label: string, description: string): string {
  const padding = Math.max(2, 22 - label.length);
  return `  ${label}${' '.repeat(padding)}${description}`;
}
