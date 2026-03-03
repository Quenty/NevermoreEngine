/**
 * Assemble the environment variables needed to run Wine processes
 * with the correct display, Mesa overrides, and prefix.
 */

import type { LinuxStudioConfig } from './linux-config.js';

/**
 * Build a complete env dictionary for running `wine` subprocesses.
 * Merges with process.env so the child inherits PATH, HOME, etc.
 */
export function buildWineEnv(
  config: LinuxStudioConfig
): Record<string, string> {
  return {
    ...stripUndefined(process.env),
    DISPLAY: config.display,
    WINEPREFIX: config.winePrefix,
    WINEARCH: 'win64',
    WINEDEBUG: '-all',
    // Suppress Mono/Gecko install dialogs that block headless runs
    WINEDLLOVERRIDES: 'mscoree=d;mshtml=d',
    // Mesa llvmpipe needs these overrides so Wine's WineD3D layer
    // sees GL 4.5 / GLSL 4.50 (required for the patched shaders)
    MESA_GL_VERSION_OVERRIDE: '4.5',
    MESA_GLSL_VERSION_OVERRIDE: '450',
  };
}

function stripUndefined(
  env: NodeJS.ProcessEnv
): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(env)) {
    if (value !== undefined) {
      result[key] = value;
    }
  }
  return result;
}
