import { describe, expect, it } from 'vitest';
import {
  describeStaleHost,
  type StaleHostBuilds,
  type StaleHostOutcome,
} from './stale-host-report.js';

const olderHost: StaleHostBuilds = {
  port: 38741,
  hostBuild: '0.24.0 build ff77f7',
  ourBuild: '0.24.0 build 1aa54d',
  isOlder: true,
};

const allOutcomes: StaleHostOutcome[] = [
  { kind: 'restarted' },
  { kind: 'unreadable', pid: 4242 },
  { kind: 'unreadable' },
  { kind: 'other-install' },
  { kind: 'remote' },
  { kind: 'process-unknown' },
  { kind: 'inside-command', pid: 4242 },
  { kind: 'unknown-cwd', pid: 4242 },
  { kind: 'in-use' },
  { kind: 'restart-failed', pid: 4242, error: new Error('did not stop') },
];

describe('describeStaleHost', () => {
  it('says an older host is still running, what that means, and what to do', () => {
    expect(
      describeStaleHost({ kind: 'process-unknown' }, olderHost)
    ).toMatchObject({
      replaced: false,
      message:
        'A bridge host from an older studio-bridge is still running, so some commands may not work.',
      fix: 'Stop the process using port 38741, then run the command again.',
    });
  });

  it('keeps build hashes out of every message and fix, and in the cause', () => {
    for (const outcome of allOutcomes) {
      const report = describeStaleHost(outcome, olderHost);

      expect(`${report.message} ${report.fix ?? ''}`).not.toMatch(
        /ff77f7|1aa54d/
      );
      expect(report.cause).toContain('ff77f7');
    }
  });

  it('gives every warning one fix', () => {
    for (const outcome of allOutcomes) {
      const report = describeStaleHost(outcome, olderHost);
      if (!report.replaced) {
        expect(report.fix).toMatch(/\.$/);
      }
    }
  });

  it('names the pid only where stopping the process is the fix', () => {
    expect(
      describeStaleHost({ kind: 'unknown-cwd', pid: 4242 }, olderHost).fix
    ).toBe('Stop it (pid 4242), then run the command again.');
    expect(describeStaleHost({ kind: 'in-use' }, olderHost).fix).not.toContain(
      '4242'
    );
  });

  it('reports a restart as done, without pids', () => {
    expect(describeStaleHost({ kind: 'restarted' }, olderHost)).toMatchObject({
      replaced: true,
      message:
        'Restarted the bridge host, which was from an older studio-bridge.',
    });
  });

  it('keeps why a restart failed for --verbose', () => {
    const report = describeStaleHost(
      { kind: 'restart-failed', pid: 4242, error: new Error('did not stop') },
      olderHost
    );

    expect(report.message).toBe(
      "A bridge host from an older studio-bridge is still running and couldn't be restarted, so some commands may not work."
    );
    expect(report.cause).toContain('did not stop');
  });

  it('points a remote host at its own machine', () => {
    expect(describeStaleHost({ kind: 'remote' }, olderHost).fix).toBe(
      "Restart 'studio-bridge serve' there with this version."
    );
  });

  it('calls a host of the same version from elsewhere another install', () => {
    expect(
      describeStaleHost(
        { kind: 'other-install' },
        { ...olderHost, isOlder: false }
      ).message
    ).toBe(
      'A bridge host from another studio-bridge install is running, so some commands may not work.'
    );
  });
});
