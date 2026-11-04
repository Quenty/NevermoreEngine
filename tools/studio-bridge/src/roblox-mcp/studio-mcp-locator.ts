import * as fs from 'fs/promises';
import * as path from 'path';
import { execa } from 'execa';

const STUDIO_EXE = 'RobloxStudioBeta.exe';
const MCP_EXE = 'StudioMCP.exe';

export interface StudioMcpLocatorOptions {
  platform?: NodeJS.Platform;
  localAppData?: string;
  readContentFolderAsync?: () => Promise<string | undefined>;
}

export async function findStudioMcpPathAsync(
  options: StudioMcpLocatorOptions = {}
): Promise<string> {
  const platform = options.platform ?? process.platform;
  if (platform !== 'win32') {
    throw new Error(
      `Finding Studio's MCP server is only supported on Windows, not ${platform}`
    );
  }

  const readContentFolderAsync =
    options.readContentFolderAsync ?? readStudioContentFolderAsync;
  const contentFolder = await readContentFolderAsync();
  if (contentFolder) {
    const versionDir = path.resolve(contentFolder, '..');
    if (await isStudioVersionDirAsync(versionDir)) {
      return path.join(versionDir, MCP_EXE);
    }
  }

  const localAppData = options.localAppData ?? process.env.LOCALAPPDATA;
  if (!localAppData) {
    throw new Error('LOCALAPPDATA is not set, so Studio cannot be found');
  }
  const versionsDir = path.join(localAppData, 'Roblox', 'Versions');
  for (const versionDir of await listVersionDirsNewestFirstAsync(versionsDir)) {
    if (await isStudioVersionDirAsync(versionDir)) {
      return path.join(versionDir, MCP_EXE);
    }
  }

  throw new Error(
    `No ${MCP_EXE} found next to ${STUDIO_EXE} under ${versionsDir}. Is Roblox Studio installed and up to date?`
  );
}

export async function readStudioContentFolderAsync(): Promise<
  string | undefined
> {
  const { stdout } = await execa(
    'reg',
    ['query', 'HKCU\\Software\\Roblox\\RobloxStudio', '/v', 'ContentFolder'],
    { reject: false }
  );
  return parseContentFolder(stdout);
}

export function parseContentFolder(regOutput: string): string | undefined {
  const match = /ContentFolder\s+REG_(?:EXPAND_)?SZ\s+(.+)$/m.exec(regOutput);
  return match?.[1].trim() || undefined;
}

async function isStudioVersionDirAsync(dir: string): Promise<boolean> {
  const [hasStudio, hasMcp] = await Promise.all([
    isFileAsync(path.join(dir, STUDIO_EXE)),
    isFileAsync(path.join(dir, MCP_EXE)),
  ]);
  return hasStudio && hasMcp;
}

async function listVersionDirsNewestFirstAsync(
  versionsDir: string
): Promise<string[]> {
  let entries: string[];
  try {
    entries = await fs.readdir(versionsDir);
  } catch {
    return [];
  }

  const dirs = await Promise.all(
    entries
      .filter((entry) => entry.startsWith('version-'))
      .map(async (entry) => {
        const dir = path.join(versionsDir, entry);
        try {
          const stat = await fs.stat(dir);
          return stat.isDirectory()
            ? { dir, mtimeMs: stat.mtimeMs }
            : undefined;
        } catch {
          return undefined;
        }
      })
  );
  return dirs
    .filter((d): d is { dir: string; mtimeMs: number } => d !== undefined)
    .sort((a, b) => b.mtimeMs - a.mtimeMs)
    .map((d) => d.dir);
}

async function isFileAsync(file: string): Promise<boolean> {
  try {
    return (await fs.stat(file)).isFile();
  } catch {
    return false;
  }
}
