import * as path from 'path';
import { fileExistsAsync } from '../../utils/nevermore-cli-utils.js';

export async function detectProjectFileAsync(
  packagePath: string
): Promise<string | undefined> {
  const candidate = path.join(packagePath, 'test', 'default.project.json');
  if (await fileExistsAsync(candidate)) {
    return 'test/default.project.json';
  }
  return undefined;
}

export async function detectScriptFileAsync(
  packagePath: string
): Promise<string | undefined> {
  const candidates = [
    'test/scripts/Server/ServerMain.server.lua',
    'test/scripts/Server/ServerMain.server.luau',
  ];
  for (const candidate of candidates) {
    if (await fileExistsAsync(path.join(packagePath, candidate))) {
      return candidate;
    }
  }
  return undefined;
}
