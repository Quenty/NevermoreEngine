import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  clearWarnings,
  createFileStore,
  getWarnings,
  ONE_DAY_MS,
  setJsonOutput,
  setShownWarningsStore,
  warnUser,
  type UserWarning,
} from './warn-user.js';

const HOUR_MS = 60 * 60 * 1000;

const autoHostWarning: UserWarning = {
  code: 'AUTO_HOST_FAILED',
  message: "Couldn't start a background bridge host.",
  fix: "Run 'studio-bridge serve' in another terminal instead.",
  cause: new Error('powershell.exe failed: ENOENT'),
  oncePerMs: ONE_DAY_MS,
};

let stateDir: string;
let now: number;
let warn: ReturnType<typeof vi.spyOn>;
let hint: ReturnType<typeof vi.spyOn>;
let verbose: ReturnType<typeof vi.spyOn>;

function startNewCommand(): void {
  clearWarnings();
  warn.mockClear();
  hint.mockClear();
  verbose.mockClear();
}

beforeEach(() => {
  stateDir = fs.mkdtempSync(path.join(os.tmpdir(), 'warn-user-'));
  now = Date.UTC(2026, 10, 11, 9);
  setShownWarningsStore(
    createFileStore(path.join(stateDir, 'shown-warnings.json')),
    () => now
  );
  warn = vi.spyOn(OutputHelper, 'warn').mockImplementation(() => {});
  hint = vi.spyOn(OutputHelper, 'hint').mockImplementation(() => {});
  verbose = vi.spyOn(OutputHelper, 'verbose').mockImplementation(() => {});
  vi.spyOn(OutputHelper, 'isVerbose').mockReturnValue(false);
});

afterEach(() => {
  clearWarnings();
  setJsonOutput(false);
  vi.restoreAllMocks();
  fs.rmSync(stateDir, { recursive: true, force: true });
});

describe('warnUser', () => {
  it('prints the message, then the fix on its own line', () => {
    warnUser({ code: 'X', message: 'Something is off.', fix: 'Do this.' });

    expect(warn).toHaveBeenCalledWith('Something is off.');
    expect(hint).toHaveBeenCalledWith('Do this.');
    expect(getWarnings()).toEqual(['Something is off. Do this.']);
  });

  it('says a warning once per command', () => {
    warnUser({ code: 'X', message: 'Something is off.' });
    warnUser({ code: 'X', message: 'Something is off.' });

    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('only collects warnings in JSON mode', () => {
    setJsonOutput(true);

    warnUser({ code: 'X', message: 'Something is off.', fix: 'Do this.' });

    expect(warn).not.toHaveBeenCalled();
    expect(getWarnings()).toEqual(['Something is off. Do this.']);
  });

  it('keeps the cause for --verbose', () => {
    warnUser(autoHostWarning);

    expect(verbose).toHaveBeenCalledWith(
      expect.stringContaining('powershell.exe failed: ENOENT')
    );
  });
});

describe('warnUser with oncePerMs', () => {
  it('shows a once-a-day warning on the first command of the day only', () => {
    warnUser(autoHostWarning);
    expect(warn).toHaveBeenCalledTimes(1);

    startNewCommand();
    now += HOUR_MS;
    warnUser(autoHostWarning);

    expect(warn).not.toHaveBeenCalled();
    expect(getWarnings()).toEqual([]);
  });

  it('shows it again a day later', () => {
    warnUser(autoHostWarning);

    startNewCommand();
    now += ONE_DAY_MS;
    warnUser(autoHostWarning);

    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('always shows it under --verbose', () => {
    warnUser(autoHostWarning);

    startNewCommand();
    now += HOUR_MS;
    vi.mocked(OutputHelper.isVerbose).mockReturnValue(true);
    warnUser(autoHostWarning);

    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('remembers it in the state directory, across processes', () => {
    warnUser(autoHostWarning);

    const saved = JSON.parse(
      fs.readFileSync(path.join(stateDir, 'shown-warnings.json'), 'utf8')
    );
    expect(saved).toEqual({ AUTO_HOST_FAILED: now });
  });

  it('tracks each warning code on its own', () => {
    warnUser(autoHostWarning);

    startNewCommand();
    warnUser({ ...autoHostWarning, code: 'OTHER', message: 'Other.' });

    expect(warn).toHaveBeenCalledWith('Other.');
  });

  it('still warns when the state file is unreadable', () => {
    fs.writeFileSync(path.join(stateDir, 'shown-warnings.json'), '{oops');

    warnUser(autoHostWarning);

    expect(warn).toHaveBeenCalledTimes(1);
  });
});
