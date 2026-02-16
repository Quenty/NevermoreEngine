import { execa } from 'execa';

export interface RojoBuildOptions {
  /** Absolute path to the rojo project JSON file */
  projectPath: string;
  /** -o flag: absolute path to output file (.rbxl / .rbxm) */
  output?: string;
  /** --plugin flag: filename placed in Studio's plugins folder */
  plugin?: string;
}

/**
 * Single call site for all rojo build invocations across the codebase.
 * Exactly one of `output` or `plugin` must be provided.
 */
export async function rojoBuildAsync(options: RojoBuildOptions): Promise<void> {
  const { projectPath, output, plugin } = options;

  if (output && plugin) {
    throw new Error('rojoBuildAsync: specify either output or plugin, not both');
  }
  if (!output && !plugin) {
    throw new Error('rojoBuildAsync: must specify either output or plugin');
  }

  const args = ['build', projectPath];

  if (output) {
    args.push('-o', output);
  } else if (plugin) {
    args.push('--plugin', plugin);
  }

  await execa('rojo', args);
}
