import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { describe, expect, it } from 'vitest';

const SRC_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..'
);

const DIRECT_WARNING_OR_ERROR =
  /\b(OutputHelper\.(warn|error)|console\.(warn|error))\(/;

const FILES_ALLOWED_TO_PRINT_DIRECTLY = new Set([
  'messages/warn-user.ts',
  'cli/adapters/cli-command-adapter.ts',
  'cli/script-executor.ts',
]);

function listSourceFiles(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return listSourceFiles(full);
    return entry.name.endsWith('.ts') && !entry.name.endsWith('.test.ts')
      ? [full]
      : [];
  });
}

describe('user-facing message channels', () => {
  it('sends warnings through warnUser and errors through the CLI adapter', () => {
    const offenders = listSourceFiles(SRC_DIR)
      .map((file) => path.relative(SRC_DIR, file).split(path.sep).join('/'))
      .filter((file) => !FILES_ALLOWED_TO_PRINT_DIRECTLY.has(file))
      .filter((file) =>
        DIRECT_WARNING_OR_ERROR.test(
          fs.readFileSync(path.join(SRC_DIR, file), 'utf8')
        )
      );

    expect(offenders).toEqual([]);
  });
});
