/**
 * Full end-to-end integration test — builds a place via rojo, injects the
 * plugin, launches Studio, and verifies output comes back through the
 * WebSocket bridge.
 *
 * Run with: npm run test:integration
 * Requires: rojo on PATH (or via aftman), Roblox Studio installed
 * Timeout: 90 seconds (Studio startup is slow)
 */

import * as path from 'path';
import * as fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { rojoBuildAsync } from '@quenty/nevermore-template-helpers';
import { StudioBridge } from '../../src/index.js';
import { findPluginsFolder } from '../../src/process/studio-process-manager.js';

// Resolve paths relative to the *source* tree, not the dist output.
// __dirname in the compiled JS points to dist/test/integration/, but the
// test-project and fixtures live in the source tree.
const __filename_resolved = decodeURIComponent(fileURLToPath(import.meta.url));
const __dirname_resolved = path.dirname(__filename_resolved);

// Walk up to the package root, then back into the source test directory
const PACKAGE_ROOT = path.resolve(__dirname_resolved, '..', '..', '..');
const TEST_PROJECT_DIR = path.join(
  PACKAGE_ROOT,
  'test',
  'integration',
  'test-project'
);
const FIXTURES_DIR = path.join(PACKAGE_ROOT, 'test', 'fixtures');
const PLACE_OUTPUT = path.join(TEST_PROJECT_DIR, 'test.rbxl');
const TIMEOUT_MS = 90_000;

async function main() {
  console.log('[smoke-test] Building test place with rojo...');
  console.log(`[smoke-test] Project dir: ${TEST_PROJECT_DIR}`);

  await rojoBuildAsync({
    projectPath: path.join(TEST_PROJECT_DIR, 'default.project.json'),
    output: PLACE_OUTPUT,
  });

  console.log(`[smoke-test] Place built: ${PLACE_OUTPUT}`);

  // Read the test script
  const scriptPath = path.join(FIXTURES_DIR, 'hello-world.lua');
  const scriptContent = await fs.readFile(scriptPath, 'utf-8');

  console.log('[smoke-test] Running StudioBridge...');

  const bridge = new StudioBridge({ placePath: PLACE_OUTPUT, timeoutMs: TIMEOUT_MS });
  let result;
  try {
    await bridge.startAsync();
    result = await bridge.executeAsync({
      scriptContent,
      onOutput: (level, body) => {
        console.log(`  [${level}] ${body}`);
      },
    });
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : String(error);
    result = {
      success: false,
      logs: `[smoke-test] Error: ${errorMessage}`,
    };
  } finally {
    await bridge.stopAsync();
  }

  console.log(`\n[smoke-test] Success: ${result.success}`);
  console.log('[smoke-test] Logs:\n' + result.logs);

  // Assertions
  if (!result.success) {
    console.error('[smoke-test] FAIL: Expected success=true');
    process.exit(1);
  }

  if (!result.logs.includes('Hello from integration test')) {
    console.error(
      '[smoke-test] FAIL: Expected logs to contain "Hello from integration test"'
    );
    process.exit(1);
  }

  // Verify plugin was cleaned up
  const pluginsFolder = findPluginsFolder();
  const remainingPlugins = (await fs.readdir(pluginsFolder)).filter((f) =>
    f.startsWith('studio-bridge-')
  );
  if (remainingPlugins.length > 0) {
    console.error(
      `[smoke-test] FAIL: Plugin files not cleaned up: ${remainingPlugins.join(', ')}`
    );
    process.exit(1);
  }

  console.log('[smoke-test] PASS: All assertions passed');

  // Clean up build artifact
  try {
    await fs.unlink(PLACE_OUTPUT);
  } catch {
    // ignore
  }
}

main().catch((err) => {
  console.error('[smoke-test] Fatal error:', err);
  process.exit(1);
});
