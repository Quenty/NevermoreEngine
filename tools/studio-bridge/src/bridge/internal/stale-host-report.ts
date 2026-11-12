import type { StaleHostReport } from './stale-host.js';

/** Why a bridge host from another studio-bridge was, or was not, replaced. */
export type StaleHostOutcome =
  | { kind: 'restarted' }
  | { kind: 'unreadable'; pid?: number }
  | { kind: 'other-install' }
  | { kind: 'remote' }
  | { kind: 'process-unknown' }
  | { kind: 'inside-command'; pid: number }
  | { kind: 'unknown-cwd'; pid: number }
  | { kind: 'in-use' }
  | { kind: 'restart-failed'; pid: number; error: unknown };

export interface StaleHostBuilds {
  port: number;
  hostBuild: string;
  ourBuild: string;
  isOlder: boolean;
}

const CONSEQUENCE = 'so some commands may not work';

export function describeStaleHost(
  outcome: StaleHostOutcome,
  builds: StaleHostBuilds
): StaleHostReport {
  const host = builds.isOlder
    ? 'A bridge host from an older studio-bridge'
    : 'A bridge host from another studio-bridge';
  const cause = `The bridge host on port ${builds.port} runs ${builds.hostBuild}; this is ${builds.ourBuild}.`;
  const stopAndRetry = (pid: number) =>
    `Stop it (pid ${pid}), then run the command again.`;
  const warning = (message: string, fix: string, detail = cause) => ({
    replaced: false,
    message,
    fix,
    cause: detail,
  });

  switch (outcome.kind) {
    case 'restarted':
      return {
        replaced: true,
        message: `Restarted the bridge host, which was ${
          builds.isOlder ? 'from an older' : 'from another'
        } studio-bridge.`,
        cause,
      };
    case 'unreadable':
      return warning(
        `${host} is running, ${CONSEQUENCE}.`,
        outcome.pid !== undefined
          ? stopAndRetry(outcome.pid)
          : `Stop the process using port ${builds.port}, then run the command again.`
      );
    case 'other-install':
      return warning(
        `A bridge host from another studio-bridge install is running, ${CONSEQUENCE}.`,
        "Restart 'studio-bridge serve' from the install you want."
      );
    case 'remote':
      return warning(
        `${host} is running on the bridge host's machine, ${CONSEQUENCE}.`,
        "Restart 'studio-bridge serve' there with this version."
      );
    case 'process-unknown':
      return warning(
        `${host} is still running, ${CONSEQUENCE}.`,
        `Stop the process using port ${builds.port}, then run the command again.`
      );
    case 'inside-command':
      return warning(
        `Another studio-bridge command, from ${
          builds.isOlder ? 'an older' : 'another'
        } version, is hosting the bridge, ${CONSEQUENCE}.`,
        `Run the command again once it ends (pid ${outcome.pid}).`
      );
    case 'unknown-cwd':
      return warning(
        `${host} is still running, ${CONSEQUENCE}.`,
        stopAndRetry(outcome.pid),
        `${cause} It was left running: its arguments may name paths relative to a directory it doesn't report.`
      );
    case 'in-use':
      return warning(
        `${host} is still in use by other commands, ${CONSEQUENCE}.`,
        'Run the command again once they finish; it restarts then.'
      );
    case 'restart-failed':
      return warning(
        `${host} is still running and couldn't be restarted, ${CONSEQUENCE}.`,
        stopAndRetry(outcome.pid),
        `${cause} ${
          outcome.error instanceof Error
            ? outcome.error.message
            : String(outcome.error)
        }`
      );
  }
}
