/** The `bridge` of a `startPlaytest` request. */
export interface PlaytestBridge {
  /** ModuleScript sources compiled ahead of time, see `wrapPrecompiledSource`. */
  precompiled: string[];
  client?: boolean;
}

export async function buildPlaytestBridgeAsync(
  scripts: string[] = [],
  options: { withClient?: boolean } = {}
): Promise<PlaytestBridge> {
  const sources = [...new Set(scripts)];
  return {
    precompiled: sources.map(wrapPrecompiledSource),
    ...(options.withClient ? { client: true } : {}),
  };
}

/**
 * A ModuleScript source returning `{ fn, source }` for `source`. The function
 * opens on the first line, so line numbers in errors match `source`. The text
 * is a long string led by a character that is cut off again, since a long
 * string drops a leading newline.
 */
export function wrapPrecompiledSource(source: string): string {
  // The string must close at its closer, not inside or straddling `source`
  let level = '';
  while (`${source}]${level}]`.indexOf(`]${level}]`) !== source.length) {
    level += '=';
  }
  return `return { fn = function(...) ${source}\nend, source = string.sub([${level}[x${source}]${level}], 2) }`;
}
