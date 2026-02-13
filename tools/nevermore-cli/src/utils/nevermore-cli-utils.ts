import { execSync } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import { execa, Options } from 'execa';
import { fileURLToPath } from 'url';

/**
 * Gets a temlate path by name
 * @param name
 * @returns
 */
export function getTemplatePathByName(name: string) {
  return path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'templates', name);
}

export async function runCommandAsync(
  initGameArgs: NevermoreGlobalArgs,
  command: string,
  args: string[],
  options?: Options
): Promise<any> {
  if (initGameArgs.dryrun) {
    OutputHelper.info(
      `[DRYRUN]: Would have ran \`${command} ${args.join(' ')}\``
    );
  } else {
    OutputHelper.info(`Running \`${command} ${args.join(' ')}\``);

    const commandExec = execa(command, args, options);

    if (commandExec.stdout) {
      commandExec.stdout.pipe(process.stdout);
    }

    if (commandExec.stderr) {
      commandExec.stderr.pipe(process.stderr);
    }

    const result = await commandExec;

    OutputHelper.info(`Finished running '${result.command}'`);

    return result;
  }
}

export async function readPackageNameAsync(
  packagePath: string
): Promise<string | undefined> {
  try {
    const content = await fs.readFile(
      path.join(packagePath, 'package.json'),
      'utf-8'
    );
    const pkg = JSON.parse(content) as { name?: string };
    return pkg.name;
  } catch {
    return undefined;
  }
}

export async function fileExistsAsync(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

export function getGitCommitShort(): string | undefined {
  try {
    return execSync('git rev-parse --short HEAD', {
      encoding: 'utf-8',
      timeout: 5000,
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  } catch {
    return undefined;
  }
}

export function timeoutAsync(ms: number, message: string): Promise<never> {
  return new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error(message)), ms)
  );
}

export async function buildPlaceNameAsync(packagePath: string): Promise<string> {
  const name =
    (await readPackageNameAsync(packagePath)) ?? path.basename(packagePath);
  const commitId = getGitCommitShort();
  if (commitId) {
    return `${name} (${commitId})`;
  }
  return name;
}
