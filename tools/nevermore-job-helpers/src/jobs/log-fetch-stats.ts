/**
 * What it took to pull a run's logs, recorded so a parser that finds nothing in
 * them can say where the shortfall happened.
 *
 * Output goes missing between a task and the parser at several caps that look
 * identical from the parser's side — the engine drops messages past a session
 * buffer it never reports, the API pages them, and a fetch can be retried. A
 * count of chars alone cannot tell a run that printed little from one whose
 * output the engine discarded, so the fetch reports its own shape too.
 */
export interface LogFetchStats {
  /**
   * HTTP GETs issued to the logs endpoint for this fetch, retries included.
   * Empty logs are retried, so this exceeds `pages` when the first tries came
   * back with nothing.
   */
  requests: number;
  /** Pages walked via `nextPageToken` on the attempt that produced the logs. */
  pages: number;
  /**
   * `luauExecutionSessionTaskLog` objects across those pages. Each one carries
   * many messages, so this stays far below the message count and is not a line
   * count — the API's per-page limit applies to these, not to messages.
   */
  entries: number;
  /** Engine messages inside those entries: one per `print`/`warn` that survived. */
  messages: number;
  /** Length of the joined log text handed to the parser. */
  chars: number;
}

/**
 * Describe how much log text arrived and what the fetch had to do to get it,
 * for a diagnostic that has already decided something is missing.
 *
 * `stats` is absent for logs that did not come from Open Cloud — a local run
 * reads them off the Studio bridge, where there is no request to count — so the
 * volume that can always be measured is reported separately from the fetch.
 */
export function describeLogVolume(
  rawLogs: string,
  stats: LogFetchStats | undefined
): string {
  const lines = rawLogs.length === 0 ? 0 : rawLogs.split('\n').length;
  const volume = `${rawLogs.length} chars, ${lines} line(s) received`;

  if (!stats) {
    return `${volume}; no fetch stats (logs did not come from Open Cloud)`;
  }

  return (
    `${volume}; fetched in ${stats.requests} API call(s) over ${stats.pages} ` +
    `page(s), ${stats.entries} log entry(ies), ${stats.messages} message(s)`
  );
}
