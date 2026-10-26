import { describe, it, expect } from 'vitest';
import {
  matchStudioProcesses,
  parseMacProcessList,
  parseWindowsProcessList,
} from './studio-process-closer.js';

describe('parseWindowsProcessList', () => {
  it('parses a single process object', () => {
    expect(
      parseWindowsProcessList(
        '{"Id":9792,"MainWindowTitle":"C:\\\\places\\\\test-place.rbxl - Roblox Studio"}'
      )
    ).toEqual([
      { pid: 9792, windowTitle: 'C:\\places\\test-place.rbxl - Roblox Studio' },
    ]);
  });

  it('parses an array and treats a null title as empty', () => {
    expect(
      parseWindowsProcessList(
        '[{"Id":1,"MainWindowTitle":"Map - Roblox Studio"},{"Id":2,"MainWindowTitle":null}]'
      )
    ).toEqual([
      { pid: 1, windowTitle: 'Map - Roblox Studio' },
      { pid: 2, windowTitle: '' },
    ]);
  });

  it('returns nothing when no Studio is running', () => {
    expect(parseWindowsProcessList('')).toEqual([]);
  });
});

describe('parseMacProcessList', () => {
  it('keeps only Studio processes', () => {
    const stdout = [
      '  101 /Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio /Users/me/test-place.rbxl',
      '  102 /usr/bin/zsh',
    ].join('\n');

    expect(parseMacProcessList(stdout)).toEqual([
      {
        pid: 101,
        windowTitle:
          '/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio /Users/me/test-place.rbxl',
      },
    ]);
  });
});

describe('matchStudioProcesses', () => {
  const processes = [
    { pid: 1, windowTitle: 'C:\\places\\test-place.rbxl - Roblox Studio' },
    { pid: 2, windowTitle: 'Map - Roblox Studio' },
    { pid: 3, windowTitle: 'Other Map - Roblox Studio' },
    { pid: 4, windowTitle: '' },
  ];

  it('matches a local file by its path', () => {
    expect(matchStudioProcesses(processes, 'test-place.rbxl')).toEqual([
      processes[0],
    ]);
  });

  it('matches a cloud place by its exact name', () => {
    expect(matchStudioProcesses(processes, 'Map')).toEqual([processes[1]]);
  });

  it('matches nothing for an unknown place', () => {
    expect(matchStudioProcesses(processes, 'Missing')).toEqual([]);
  });
});
