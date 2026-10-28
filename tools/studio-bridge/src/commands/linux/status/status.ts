/**
 * `linux status` — check the health of the Linux/Wine environment for
 * running Studio.
 */

import * as fs from 'fs/promises';
import { defineCommand } from '../../framework/define-command.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { checkLinuxEnvironmentAsync } from '../../../linux/linux-env-guard.js';

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface StatusArgs {}

interface PrerequisiteStatus {
  name: string;
  available: boolean;
  version?: string;
  hint?: string;
}

export interface StatusResult {
  /** False only when the check could not run; an unhealthy environment still reports. */
  success: boolean;
  healthy: boolean;
  summary: string;
  error?: string;
  prerequisites: PrerequisiteStatus[];
  display: { name?: string; xvfb: boolean; openbox: boolean };
  studio: {
    dir?: string;
    installed: boolean;
    version?: string;
    fflags: boolean;
    shaders: boolean;
  };
  auth: {
    writeCredExe: boolean;
    winePrefix: boolean;
    credentialsInjected: boolean;
  };
}

async function fileExistsAsync(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

function unhealthy(error: string): StatusResult {
  return {
    success: false,
    healthy: false,
    summary: error,
    error,
    prerequisites: [],
    display: { xvfb: false, openbox: false },
    studio: { installed: false, fflags: false, shaders: false },
    auth: {
      writeCredExe: false,
      winePrefix: false,
      credentialsInjected: false,
    },
  };
}

export async function statusHandlerAsync(
  _args: StatusArgs
): Promise<StatusResult> {
  try {
    const envError = await checkLinuxEnvironmentAsync();
    if (envError) {
      return unhealthy(envError);
    }

    const linux = await import('../../../linux/index.js');
    const config = linux.resolveLinuxConfig();

    const prerequisites = linux.checkPrerequisites();

    const displayNum = config.display.replace(':', '');
    const xvfb = linux.isXvfbRunning(displayNum);
    const openbox = linux.isOpenboxRunning();

    const installed = await fileExistsAsync(config.studioExe);
    const { readInstalledVersionAsync } = await import(
      '../../../linux/linux-version-resolver.js'
    );
    const version = await readInstalledVersionAsync(config.studioDir);
    const fflags = await fileExistsAsync(config.clientSettingsPath);
    const shaders = await fileExistsAsync(
      `${config.shadersDir}/shaders_glsl3.pack`
    );

    const writeCredExe = await fileExistsAsync(config.writeCredExe);
    const wineRegPath = `${config.winePrefix}/user.reg`;
    const winePrefix = await fileExistsAsync(wineRegPath);
    const credentialsInjected =
      winePrefix &&
      (await fs.readFile(wineRegPath, 'utf-8')).includes('RobloxStudioAuth');

    const healthy =
      prerequisites.every((p) => p.available) &&
      xvfb &&
      openbox &&
      installed &&
      credentialsInjected;

    return {
      success: true,
      healthy,
      summary: healthy
        ? 'Environment is ready for Studio.'
        : 'Environment has issues. See above for details.',
      prerequisites,
      display: { name: config.display, xvfb, openbox },
      studio: {
        dir: config.studioDir,
        installed,
        version: version ?? undefined,
        fflags,
        shaders,
      },
      auth: { writeCredExe, winePrefix, credentialsInjected },
    };
  } catch (err) {
    return unhealthy(err instanceof Error ? err.message : String(err));
  }
}

export function formatStatusText(result: StatusResult): string {
  if (result.error) return OutputHelper.formatError(result.error);

  const { prerequisites, display, studio, auth } = result;
  const lines = ['System prerequisites:'];
  for (const p of prerequisites) {
    lines.push(
      p.available
        ? `  OK  ${p.name}${p.version ? ` (${p.version})` : ''}`
        : OutputHelper.formatError(`  MISSING  ${p.name} — ${p.hint}`)
    );
  }

  lines.push(
    '',
    'Display:',
    `  Xvfb (${display.name}): ${display.xvfb ? 'running' : 'not running'}`,
    `  openbox: ${display.openbox ? 'running' : 'not running'}`,
    '',
    'Studio installation:',
    `  ${studio.dir}: ${studio.installed ? 'installed' : 'not found'}`
  );
  if (studio.version) lines.push(`  Version: ${studio.version}`);
  lines.push(
    `  FFlags: ${studio.fflags ? 'configured' : 'not found'}`,
    `  Shaders: ${studio.shaders ? 'present' : 'not found'}`,
    '',
    'Authentication:',
    `  write-cred.exe: ${auth.writeCredExe ? 'compiled' : 'not found'}`,
    auth.winePrefix
      ? `  Wine credentials: ${
          auth.credentialsInjected ? 'present' : 'not injected'
        }`
      : '  Wine prefix: not initialized',
    '',
    result.healthy ? result.summary : OutputHelper.formatWarning(result.summary)
  );

  return lines.join('\n');
}

export const linuxStatusCommand = defineCommand<StatusArgs, StatusResult>({
  group: 'linux',
  name: 'status',
  description:
    'Check Linux/Wine environment health for Studio (within Docker image or Linux with Wine)',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {},
  cli: {
    format: formatStatusText,
  },
  handler: async (args) => statusHandlerAsync(args),
});
