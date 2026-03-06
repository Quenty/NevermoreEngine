/**
 * `linux setup` — install Wine dependencies and Roblox Studio for headless
 * Linux operation.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { checkLinuxEnvironmentAsync } from '../../../linux/linux-env-guard.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface SetupArgs {
  'install-deps': boolean;
  'studio-version'?: string;
  'studio-dir'?: string;
  'skip-shaders': boolean;
  force: boolean;
}

interface SetupResult {
  success: boolean;
  summary: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function setupHandlerAsync(args: SetupArgs): Promise<SetupResult> {
  try {
    const envError = await checkLinuxEnvironmentAsync();
    if (envError) {
      OutputHelper.error(envError);
      process.exit(1);
    }

    const linux = await import('../../../linux/index.js');
    const config = linux.resolveLinuxConfig();

    // Override studioDir if provided
    if (args['studio-dir']) {
      config.studioDir = args['studio-dir'];
    }

    // Step 1: Install system deps
    if (args['install-deps']) {
      OutputHelper.info('Installing system dependencies...');
      await linux.installDependenciesAsync();
    }

    // Step 2: Check prerequisites
    OutputHelper.info('Checking prerequisites...');
    const results = linux.checkPrerequisites();
    const missing = results.filter((r) => !r.available);
    if (missing.length > 0) {
      for (const m of missing) {
        OutputHelper.error(`Missing: ${m.name} — ${m.hint}`);
      }
      if (!args['install-deps']) {
        OutputHelper.hint(
          'Run with --install-deps to install missing dependencies'
        );
      }
      return {
        success: false,
        summary: `Missing prerequisites: ${missing.map((m) => m.name).join(', ')}`,
      };
    }
    OutputHelper.info('All prerequisites satisfied.');

    // Step 3: Resolve version
    const version = await linux.resolveStudioVersionAsync(args['studio-version']);
    OutputHelper.info(`Studio version: ${version}`);

    // Step 4: Check if already installed
    const { readInstalledVersionAsync } = await import(
      '../../../linux/linux-version-resolver.js'
    );
    const installed = await readInstalledVersionAsync(config.studioDir);
    if (installed === version && !args.force) {
      OutputHelper.info(
        `Studio ${version} already installed. Use --force to reinstall.`
      );
    } else {
      await linux.installStudioAsync(config, version);
    }

    // Step 5: Patch shaders
    if (!args['skip-shaders']) {
      await linux.patchShadersAsync(config);
    }

    // Step 6: Write FFlags
    await linux.writeFflagsAsync(config);

    // Step 7: Compile write-cred.exe
    const { compileWriteCredAsync } = await import(
      '../../../linux/linux-credential-writer.js'
    );
    await compileWriteCredAsync(config);

    // Step 8: Start display
    await linux.ensureDisplayAsync(config);
    await linux.ensureWindowManagerAsync(config);

    OutputHelper.info('Linux setup complete.');
    OutputHelper.hint(
      'Next: run "studio-bridge linux auth" to inject credentials'
    );

    return { success: true, summary: `Studio ${version} installed and configured` };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    OutputHelper.error(message);
    return { success: false, summary: message };
  }
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const linuxSetupCommand = defineCommand<SetupArgs, SetupResult>({
  group: 'linux',
  name: 'setup',
  description: 'Install Wine + Roblox Studio for headless Linux operation (within Docker image or Linux with Wine)',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    'install-deps': arg.flag({ description: 'Install system dependencies via apt-get (requires sudo)' }),
    'studio-version': arg.option({ description: 'Studio version hash (default: latest from CDN)' }),
    'studio-dir': arg.option({ description: 'Override Studio installation directory' }),
    'skip-shaders': arg.flag({ description: 'Skip shader patching' }),
    force: arg.flag({ description: 'Force reinstall even if already installed' }),
  },
  handler: async (args) => setupHandlerAsync(args),
});
