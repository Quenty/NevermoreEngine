/**
 * Binary-patch GLSL shaders from #version 150 to #version 420.
 *
 * Mesa's llvmpipe strictly enforces the GLSL spec — shaders using
 * unpackHalf2x16() (GLSL 4.20+) but declaring #version 150 are rejected.
 * Both version strings are exactly 12 bytes, so the patch is a safe
 * in-place replacement.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { LinuxStudioConfig } from './linux-config.js';

const SHADER_PACK_NAME = 'shaders_glsl3.pack';
const OLD_VERSION = Buffer.from('#version 150');
const NEW_VERSION = Buffer.from('#version 420');

/**
 * Patch the GLSL3 shader pack in-place, replacing all occurrences of
 * `#version 150` with `#version 420`.
 *
 * Returns the number of replacements made.
 */
export async function patchShadersAsync(
  config: LinuxStudioConfig
): Promise<number> {
  const shaderPath = path.join(config.shadersDir, SHADER_PACK_NAME);

  let data: Buffer;
  try {
    data = await fs.readFile(shaderPath);
  } catch {
    throw new Error(`Shader pack not found: ${shaderPath}`);
  }

  let count = 0;
  let offset = 0;

  while (true) {
    const idx = data.indexOf(OLD_VERSION, offset);
    if (idx === -1) break;
    NEW_VERSION.copy(data, idx);
    count++;
    offset = idx + NEW_VERSION.length;
  }

  if (count === 0) {
    OutputHelper.verbose('Shaders already patched (no #version 150 found).');
    return 0;
  }

  await fs.writeFile(shaderPath, data);
  OutputHelper.info(`Patched ${count} shaders (#version 150 → #version 420).`);
  return count;
}
