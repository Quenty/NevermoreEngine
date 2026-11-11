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
  /**
   * Re-resolve `"saved"`/`"published"` base place pins rather than reusing the
   * version `deploy.nevermore.lock.json` holds, and write the new answer back.
   * What a watch-dispatched rebuild passes, since the lock is otherwise exactly
   * what stops it from picking up the base place edit that triggered it.
   */
  refreshBasePlace: boolean;
}
