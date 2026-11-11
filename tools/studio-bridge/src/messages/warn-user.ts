import * as fs from 'fs';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { getStateDir } from '../state-dir.js';
import { formatCause } from './describe-error.js';

export const ONE_DAY_MS = 24 * 60 * 60 * 1000;

/** A warning in the user's terms. With `oncePerMs`, it shows at most that often, except under --verbose. */
export interface UserWarning {
  code: string;
  message: string;
  fix?: string;
  cause?: unknown;
  oncePerMs?: number;
}

export interface ShownWarningsStore {
  read(): Record<string, number>;
  write(shownAt: Record<string, number>): void;
}

let isJsonOutput = false;
const shownThisRun = new Set<string>();
const warnings: string[] = [];
let store: ShownWarningsStore = createFileStore(
  path.join(getStateDir(), 'shown-warnings.json')
);
let now = (): number => Date.now();

export function setJsonOutput(json: boolean): void {
  isJsonOutput = json;
}

export function isJsonOutputEnabled(): boolean {
  return isJsonOutput;
}

export function warnUser(warning: UserWarning): void {
  if (shownThisRun.has(warning.message)) return;
  if (isQuietFor(warning) && !OutputHelper.isVerbose()) return;
  shownThisRun.add(warning.message);
  if (warning.oncePerMs !== undefined) {
    rememberShown(warning.code);
  }

  warnings.push(
    warning.fix ? `${warning.message} ${warning.fix}` : warning.message
  );
  if (isJsonOutput) return;
  OutputHelper.warn(warning.message);
  if (warning.fix) OutputHelper.hint(warning.fix);
  if (warning.cause !== undefined) {
    OutputHelper.verbose(formatCause(warning.cause));
  }
}

export function getWarnings(): readonly string[] {
  return warnings;
}

export function clearWarnings(): void {
  warnings.length = 0;
  shownThisRun.clear();
}

export function setShownWarningsStore(
  value: ShownWarningsStore,
  clock: () => number = () => Date.now()
): void {
  store = value;
  now = clock;
}

export function createFileStore(filePath: string): ShownWarningsStore {
  return {
    read: () => {
      try {
        return JSON.parse(fs.readFileSync(filePath, 'utf8'));
      } catch {
        return {};
      }
    },
    write: (shownAt) => {
      try {
        fs.mkdirSync(path.dirname(filePath), { recursive: true });
        fs.writeFileSync(filePath, JSON.stringify(shownAt));
      } catch {}
    },
  };
}

function isQuietFor(warning: UserWarning): boolean {
  if (warning.oncePerMs === undefined) return false;
  const shownAt = store.read()[warning.code];
  return typeof shownAt === 'number' && now() - shownAt < warning.oncePerMs;
}

function rememberShown(code: string): void {
  store.write({ ...store.read(), [code]: now() });
}
