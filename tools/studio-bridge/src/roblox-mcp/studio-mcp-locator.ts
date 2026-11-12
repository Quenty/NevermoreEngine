import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { execa } from 'execa';

const STUDIO_EXE = 'RobloxStudioBeta.exe';
const MCP_EXE = 'StudioMCP.exe';

export class StudioMcpUnsupportedError extends Error {}

export interface StudioMcpLaunch {
  command: string;
  args: string[];
  env?: Record<string, string>;
}

export interface StudioMcpLocatorOptions {
  platform?: NodeJS.Platform;
  localAppData?: string;
  readContentFolderAsync?: () => Promise<string | undefined>;
  macCandidates?: string[];
  linuxStudioDir?: string;
  linuxEnv?: Record<string, string>;
}

export async function findStudioMcpLaunchAsync(
  options: StudioMcpLocatorOptions = {}
): Promise<StudioMcpLaunch> {
  const platform = options.platform ?? process.platform;
  if (platform === 'win32') {
    return { command: await _findWindowsAsync(options), args: [] };
  }
  if (platform === 'darwin') {
    return { command: await _findMacAsync(options), args: [] };
  }
  if (platform === 'linux') {
    return _findLinuxAsync(options);
  }
  throw new StudioMcpUnsupportedError(
    `Studio's MCP server is not available on ${platform}`
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

async function _findWindowsAsync(
  options: StudioMcpLocatorOptions
): Promise<string> {
  const readContentFolderAsync =
    options.readContentFolderAsync ?? readStudioContentFolderAsync;
  const contentFolder = await readContentFolderAsync();
  if (contentFolder) {
    const versionDir = path.resolve(contentFolder, '..');
    if (await _isStudioVersionDirAsync(versionDir)) {
      return path.join(versionDir, MCP_EXE);
    }
  }

  const localAppData = options.localAppData ?? process.env.LOCALAPPDATA;
  if (!localAppData) {
    throw new Error("LOCALAPPDATA isn't set, so Roblox Studio can't be found");
  }
  const versionsDir = path.join(localAppData, 'Roblox', 'Versions');
  for (const versionDir of await _listVersionDirsNewestFirstAsync(
    versionsDir
  )) {
    if (await _isStudioVersionDirAsync(versionDir)) {
      return path.join(versionDir, MCP_EXE);
    }
  }

  throw new Error(
    `No installed Roblox Studio ships an MCP server (${MCP_EXE} beside ${STUDIO_EXE} under ${versionsDir}); update Studio to get one`
  );
}

async function _findMacAsync(
  options: StudioMcpLocatorOptions
): Promise<string> {
  const candidates = options.macCandidates ?? [
    '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP',
    path.join(
      os.homedir(),
      'Applications/RobloxStudio.app/Contents/MacOS/StudioMCP'
    ),
  ];
  for (const candidate of candidates) {
    if (await _isFileAsync(candidate)) {
      return candidate;
    }
  }
  throw new Error(
    `Roblox Studio's app bundle has no MCP server (${candidates.join(
      ', '
    )}); update Studio to get one`
  );
}

async function _findLinuxAsync(
  options: StudioMcpLocatorOptions
): Promise<StudioMcpLaunch> {
  let studioDir = options.linuxStudioDir;
  let env = options.linuxEnv;
  if (studioDir === undefined) {
    const { resolveLinuxConfig } = await import('../linux/linux-config.js');
    const { buildWineEnv } = await import('../linux/linux-wine-env.js');
    const config = resolveLinuxConfig();
    studioDir = config.studioDir;
    env ??= buildWineEnv(config);
  }

  const exe = path.join(studioDir, MCP_EXE);
  if (!(await _isFileAsync(exe))) {
    throw new Error(
      `The Studio under Wine has no MCP server (no ${MCP_EXE} in ${studioDir}); run 'studio-bridge linux setup --force' to install a newer Studio`
    );
  }
  return { command: 'wine', args: [exe], env };
}

async function _isStudioVersionDirAsync(dir: string): Promise<boolean> {
  const [hasStudio, hasMcp] = await Promise.all([
    _isFileAsync(path.join(dir, STUDIO_EXE)),
    _isFileAsync(path.join(dir, MCP_EXE)),
  ]);
  return hasStudio && hasMcp;
}

async function _listVersionDirsNewestFirstAsync(
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

async function _isFileAsync(file: string): Promise<boolean> {
  try {
    return (await fs.stat(file)).isFile();
  } catch {
    return false;
  }
}
