/**
 * Global arguments available to all commands.
 */
export interface NevermoreGlobalArgs {
  yes: boolean;
  dryrun: boolean;
  verbose: boolean;
  /**
   * Refuse to resolve a base place version that `deploy.nevermore.lock.json`
   * does not already pin. Off by default, including in CI — a repo that has not
   * committed a lock file yet must not start failing builds.
   */
  frozenLockfile: boolean;
}
