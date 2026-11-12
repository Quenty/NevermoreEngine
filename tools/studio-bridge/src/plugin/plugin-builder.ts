import * as fs from 'fs/promises';
import * as path from 'path';
import type {
  BuildContext,
  RojoBuildOptions,
} from '@quenty/nevermore-template-helpers/build';
import { getPluginPackageDir } from './plugin-package-dir.js';

export const PLUGIN_BUILD_TOKENS = [
  'PLUGIN_VERSION',
  'PORT',
  'SESSION_ID',
  'EPHEMERAL',
] as const;

export type PluginBuildValues = Partial<
  Record<typeof PLUGIN_BUILD_TOKENS[number], string>
>;

/** Where the built `.rbxm` goes. */
export type PluginBuildTarget = Pick<
  RojoBuildOptions,
  'output' | 'plugin' | 'pluginsFolder'
>;

const MODEL_FILE_NAME = 'StudioBridgePlugin.rbxmx';

export async function buildPluginAsync(
  buildContext: BuildContext,
  values: PluginBuildValues,
  target: PluginBuildTarget
): Promise<string | undefined> {
  const pluginPackageDir = getPluginPackageDir();
  const modelPath = buildContext.resolvePath(MODEL_FILE_NAME);
  await buildContext.rojoBuildAsync({
    projectPath: path.join(pluginPackageDir, 'default.project.json'),
    output: modelPath,
    cwd: pluginPackageDir,
  });

  const model = await fs.readFile(modelPath, 'utf-8');
  await fs.writeFile(modelPath, fillPluginBuildTokens(model, values), 'utf-8');

  const projectPath = await buildContext.writeFileAsync(
    'plugin.project.json',
    JSON.stringify({
      name: 'StudioBridgePlugin',
      tree: { $path: MODEL_FILE_NAME },
    })
  );
  return buildContext.rojoBuildAsync({
    projectPath,
    ...target,
    cwd: pluginPackageDir,
  });
}

export function fillPluginBuildTokens(
  model: string,
  values: PluginBuildValues
): string {
  let filled = model;
  for (const token of PLUGIN_BUILD_TOKENS) {
    const placeholder = `{{${token}}}`;
    const value = values[token] ?? '';
    if (!/^[\w.-]*$/.test(value)) {
      throw new Error(`Invalid plugin build value for ${token}: '${value}'`);
    }
    if (!filled.includes(placeholder)) {
      throw new Error(
        `The built studio-bridge plugin has no ${placeholder} to fill in`
      );
    }
    filled = filled.replaceAll(placeholder, value);
  }
  return filled;
}
