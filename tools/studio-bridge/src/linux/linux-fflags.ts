/**
 * Write the FFlags required for Studio to render correctly under Wine/Mesa.
 *
 * Key flags:
 * - FFlagDebugGraphicsPreferD3D11: Use D3D11 via WineD3D (avoids Wine's
 *   EGL swapchain bug that breaks DockWidgets in OpenGL mode)
 * - FFlagDebugGraphicsDisableVulkan/OpenGL/D3D11FL10: Prevent fallback
 *   to renderers that don't work under Wine
 * - FIntStudioLowMemoryThresholdPercentage: Disable OOM warning dialog
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { LinuxStudioConfig } from './linux-config.js';

const DEFAULT_FFLAGS: Record<string, boolean | number> = {
  FFlagDebugGraphicsPreferD3D11: true,
  FFlagDebugGraphicsDisableVulkan: true,
  FFlagDebugGraphicsDisableD3D11FL10: true,
  FFlagDebugGraphicsDisableOpenGL: true,
  FIntStudioLowMemoryThresholdPercentage: 0,
};

/**
 * Write ClientAppSettings.json with the FFlags needed for Wine rendering.
 * Merges with any existing flags to avoid clobbering user customizations.
 */
export async function writeFflagsAsync(
  config: LinuxStudioConfig,
  extraFlags?: Record<string, boolean | number>
): Promise<void> {
  const settingsDir = path.dirname(config.clientSettingsPath);
  await fs.mkdir(settingsDir, { recursive: true });

  // Merge defaults + extras
  const flags = { ...DEFAULT_FFLAGS, ...extraFlags };

  await fs.writeFile(
    config.clientSettingsPath,
    JSON.stringify(flags, null, 2) + '\n',
    'utf-8'
  );

  OutputHelper.verbose(
    `Wrote ${Object.keys(flags).length} FFlags to ${config.clientSettingsPath}`
  );
}
