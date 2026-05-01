/**
 * Check system prerequisites for running Studio under Wine on Linux.
 */

import { execSync } from 'child_process';
import { OutputHelper } from '@quenty/cli-output-helpers';

export interface PrerequisiteResult {
  name: string;
  available: boolean;
  version?: string;
  hint?: string;
}

const PREREQUISITES: Array<{
  name: string;
  command: string;
  hint: string;
}> = [
  {
    name: 'wine',
    command: 'wine --version',
    hint: 'Install Wine 11+: https://wiki.winehq.org/Download',
  },
  {
    name: 'Xvfb',
    command: 'Xvfb -help 2>&1 | head -1',
    hint: 'apt-get install xvfb',
  },
  {
    name: 'openbox',
    command: 'openbox --version',
    hint: 'apt-get install openbox',
  },
  {
    name: 'x86_64-w64-mingw32-gcc',
    command: 'x86_64-w64-mingw32-gcc --version',
    hint: 'apt-get install gcc-mingw-w64-x86-64',
  },
  {
    name: 'unzip',
    command: 'unzip -v 2>&1 | head -1',
    hint: 'apt-get install unzip',
  },
];

/**
 * Check all required tools are present. Returns an array of results
 * including version strings where parseable.
 */
export function checkPrerequisites(): PrerequisiteResult[] {
  return PREREQUISITES.map(({ name, command, hint }) => {
    try {
      const output = execSync(command, {
        encoding: 'utf-8',
        timeout: 5000,
        stdio: ['pipe', 'pipe', 'pipe'],
      }).trim();

      const version = extractVersion(output);
      return { name, available: true, version };
    } catch {
      return { name, available: false, hint };
    }
  });
}

/**
 * Returns true if all prerequisites are satisfied.
 */
export function allPrerequisitesMet(): boolean {
  return checkPrerequisites().every((r) => r.available);
}

function extractVersion(output: string): string | undefined {
  const match = output.match(/(\d+\.\d+[\w.-]*)/);
  return match?.[1];
}

/**
 * Install missing system dependencies. Requires sudo.
 * Only runs on Debian/Ubuntu (apt-get).
 */
export async function installDependenciesAsync(): Promise<void> {
  const { execa } = await import('execa');

  await execa('sudo', ['dpkg', '--add-architecture', 'i386'], {
    stdio: 'inherit',
  });

  // Try WineHQ repo first for latest builds, fall back to distro packages
  let useWineHQ = false;
  try {
    await execa('sudo', ['mkdir', '-pm755', '/etc/apt/keyrings'], {
      stdio: 'inherit',
    });
    await execa(
      'sudo',
      [
        'curl',
        '-sL',
        'https://dl.winehq.org/wine-builds/winehq.key',
        '-o',
        '/etc/apt/keyrings/winehq-archive.key',
      ],
      { stdio: 'inherit' }
    );

    let codename = 'noble';
    try {
      codename = execSync('lsb_release -cs', { encoding: 'utf-8' }).trim();
    } catch {
      // Fall back to noble (Ubuntu 24.04)
    }

    await execa(
      'sudo',
      [
        'curl',
        '-sfL',
        `https://dl.winehq.org/wine-builds/ubuntu/dists/${codename}/winehq-${codename}.sources`,
        '-o',
        `/etc/apt/sources.list.d/winehq-${codename}.sources`,
      ],
      { stdio: 'inherit' }
    );
    useWineHQ = true;
  } catch {
    OutputHelper.warn(
      'WineHQ repo not available for this distro, using system packages'
    );
  }

  await execa('sudo', ['apt-get', 'update'], { stdio: 'inherit' });

  const winePackage = useWineHQ ? 'winehq-stable' : 'wine';
  await execa(
    'sudo',
    [
      'apt-get',
      'install',
      '-y',
      winePackage,
      'xvfb',
      'mesa-utils',
      'openbox',
      'gcc-mingw-w64-x86-64',
      'unzip',
    ],
    { stdio: 'inherit' }
  );
}
