/**
 * Transparent Docker delegation for `process run` on Linux environments
 * without Wine. Detects when Docker is available and delegates the entire
 * command to the pre-built container image.
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { validateCookieAsync } from '@quenty/nevermore-cli-helpers';
import type { ExecuteScriptOptions } from '../cli/script-executor.js';

const DOCKER_IMAGE_BASE = 'ghcr.io/quenty/nevermore-studio-linux';
const CHECK_TIMEOUT_MS = 5_000;

/**
 * Resolves the Docker image to use. Defaults to :latest, but can be
 * overridden with STUDIO_BRIDGE_DOCKER_TAG (e.g. "canary-feat-my-branch").
 */
function resolveDockerImage(): string {
  const tag = process.env.STUDIO_BRIDGE_DOCKER_TAG ?? 'latest';
  return `${DOCKER_IMAGE_BASE}:${tag}`;
}

/**
 * Returns true if the current environment should delegate to Docker
 * (Linux without Wine, but with Docker available).
 */
export async function shouldDelegateToDockerAsync(): Promise<boolean> {
  if (os.platform() !== 'linux') {
    return false;
  }

  // Check if Wine is available locally
  try {
    await execa('wine', ['--version'], { timeout: CHECK_TIMEOUT_MS });
    return false; // Wine works, use local path
  } catch {
    // Wine not available, check Docker
  }

  try {
    await execa('docker', ['info'], { timeout: CHECK_TIMEOUT_MS, stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

/**
 * Delegates script execution to the Docker container. Streams stdio
 * transparently and propagates the exit code. Does not return — calls
 * process.exit().
 */
export async function delegateToDockerAsync(
  options: ExecuteScriptOptions,
): Promise<never> {
  const cookie = process.env.ROBLOSECURITY;
  if (!cookie) {
    OutputHelper.error(
      'ROBLOSECURITY environment variable is required for Docker delegation.',
    );
    process.exit(1);
  }

  const validation = await validateCookieAsync(cookie);
  if (!validation.valid) {
    if (validation.reason === 'network_error') {
      OutputHelper.warn('Could not validate ROBLOSECURITY cookie (network error). Continuing anyway.');
    } else {
      OutputHelper.error(
        `ROBLOSECURITY cookie is invalid or expired (HTTP ${validation.status}). Update the cookie and try again.`,
      );
      process.exit(1);
    }
  }

  const image = resolveDockerImage();
  await ensureImageAsync(image);

  const cwd = process.cwd();
  const args = await buildDockerRunArgsAsync(options, cwd, cookie, image);

  // Log args without the cookie value
  const safeArgs = args.map(a =>
    a.startsWith('ROBLOSECURITY=') ? 'ROBLOSECURITY=<redacted>' : a,
  );
  OutputHelper.verbose(`[StudioBridge] docker run args: ${safeArgs.join(' ')}`);

  const result = await execa('docker', args, {
    stdio: 'inherit',
    reject: false,
  });

  process.exit(result.exitCode ?? 1);
}

const STALE_DAYS = 7;

/**
 * Ensures the Docker image is available locally, pulling if needed.
 * Warns if the local image is older than STALE_DAYS.
 */
async function ensureImageAsync(image: string): Promise<void> {
  try {
    const { stdout } = await execa('docker', [
      'image', 'inspect', '--format', '{{.Created}}', image,
    ]);
    const created = new Date(stdout.trim());
    const ageDays = (Date.now() - created.getTime()) / (1000 * 60 * 60 * 24);
    if (ageDays > STALE_DAYS) {
      OutputHelper.warn(
        `Docker image is ${Math.floor(ageDays)} days old. Run 'docker pull ${image}' to update.`,
      );
    }
  } catch {
    OutputHelper.info(`Pulling ${image}...`);
    await execa('docker', ['pull', image], { stdio: 'inherit' });
  }
}

/**
 * Builds the docker run argument array, writing inline script content
 * to a temp file if needed.
 */
export async function buildDockerRunArgsAsync(
  options: ExecuteScriptOptions,
  cwd: string,
  cookie: string,
  image: string = `${DOCKER_IMAGE_BASE}:latest`,
): Promise<string[]> {
  const { scriptContent, placePath, timeoutMs, verbose } = options;

  // Write script to a temp file in CWD to avoid shell escaping issues
  let tmpFile: string | undefined;
  let scriptFilePath: string;

  if (options.filePath) {
    scriptFilePath = path.resolve(options.filePath);
    // Validate file is within CWD
    if (!scriptFilePath.startsWith(cwd)) {
      OutputHelper.error(
        `Cannot delegate: file ${scriptFilePath} is outside working directory ${cwd}`,
      );
      process.exit(1);
    }
  } else {
    tmpFile = path.join(cwd, `.studio-bridge-tmp-${process.pid}.lua`);
    await fs.writeFile(tmpFile, scriptContent, 'utf-8');
    scriptFilePath = tmpFile;

    // Register cleanup
    const cleanup = async () => {
      try {
        await fs.unlink(tmpFile!);
      } catch {
        // Ignore
      }
    };
    process.on('exit', () => { void cleanup(); });
    process.on('SIGINT', () => { void cleanup(); });
    process.on('SIGTERM', () => { void cleanup(); });
  }

  const innerArgs = [
    'studio-bridge', 'linux', 'inject-credentials',
    '&&',
    'studio-bridge', 'process', 'run',
    '--file', scriptFilePath,
    '--timeout', String(timeoutMs),
  ];

  if (placePath) {
    const resolvedPlace = path.resolve(placePath);
    if (!resolvedPlace.startsWith(cwd)) {
      OutputHelper.error(
        `Cannot delegate: place file ${resolvedPlace} is outside working directory ${cwd}`,
      );
      process.exit(1);
    }
    innerArgs.push('--place', resolvedPlace);
  }

  if (verbose) {
    innerArgs.push('--verbose');
  }

  // Docker-level timeout: script timeout + 60s buffer for auth/setup
  const dockerTimeoutSec = Math.ceil((timeoutMs + 60_000) / 1000);

  return [
    'run', '--rm', '--init',
    '--stop-timeout', String(dockerTimeoutSec),
    '-e', `ROBLOSECURITY=${cookie}`,
    '-v', `${cwd}:${cwd}`,
    '-w', cwd,
    image,
    'bash', '-c', innerArgs.join(' '),
  ];
}
