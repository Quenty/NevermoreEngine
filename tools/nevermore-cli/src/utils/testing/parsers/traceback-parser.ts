import { OutputHelper } from '@quenty/cli-output-helpers';

export interface AttributedTraceback {
  /** First line of the error, before the stack. */
  message: string;
  /** Roblox instance path of the topmost frame, e.g. "ServerScriptService.Foo.Bar". */
  source?: string;
  /** Root of that path, which names the package the frame belongs to. */
  owner?: string;
  /** Frames kept for display, topmost first. */
  frames: string[];
  /** How many times this same traceback appeared. */
  count: number;
}

const STACK_BEGIN = /^\s*Stack Begin\s*$/;
const STACK_END = /^\s*Stack End\s*$/;
// Script 'ServerScriptService.EggHunt2026.game.Server.Foo', Line 365 - function bar
const FRAME = /Script\s+'(?:\[string\s+")?([^'"\]]+)/;

const MAX_FRAMES = 4;

/**
 * Pull tracebacks out of log output and attribute each to its owning package.
 *
 * Attribution reads the script path in the frames rather than the position of
 * the traceback in the log. Position is unreliable: a deferred callback can
 * fire during a later package's section, which is why batch mode previously
 * gave up on tracebacks entirely.
 */
export function parseTracebacks(rawOutput: string): AttributedTraceback[] {
  if (!rawOutput) {
    return [];
  }

  const lines = OutputHelper.stripAnsi(rawOutput).split('\n');
  const bySignature = new Map<string, AttributedTraceback>();

  for (let i = 0; i < lines.length; i++) {
    if (!STACK_BEGIN.test(lines[i])) {
      continue;
    }

    // The error text sits on the line above "Stack Begin".
    const message = (lines[i - 1] ?? '').trim();

    const frames: string[] = [];
    let source: string | undefined;
    for (let j = i + 1; j < lines.length && !STACK_END.test(lines[j]); j++) {
      const frame = lines[j].trim();
      if (!frame) {
        continue;
      }
      if (frames.length < MAX_FRAMES) {
        frames.push(frame);
      }
      if (!source) {
        source = FRAME.exec(frame)?.[1];
      }
    }

    // One bug fires per player and per frame, so the same traceback can appear
    // hundreds of times. Collapse by signature and count instead of printing
    // every copy.
    const signature = `${message}::${frames[0] ?? ''}`;
    const existing = bySignature.get(signature);
    if (existing) {
      existing.count++;
      continue;
    }

    bySignature.set(signature, {
      message,
      source,
      owner: source ? ownerOf(source) : undefined,
      frames,
      count: 1,
    });
  }

  return [...bySignature.values()];
}

/**
 * Name the package a script path belongs to.
 *
 * Batch places hold each package under its own root, so the segment below the
 * service is the package.
 */
export function ownerOf(scriptPath: string): string | undefined {
  const parts = scriptPath.split('.');
  return parts.length >= 2 ? parts[1] : undefined;
}

/** Render tracebacks for a human, newest information first and bounded. */
export function formatTracebacks(
  tracebacks: AttributedTraceback[],
  maxShown = 5
): string {
  if (tracebacks.length === 0) {
    return '';
  }

  const lines: string[] = [];
  const shown = tracebacks.slice(0, maxShown);

  for (const traceback of shown) {
    const where = traceback.source ? ` (${traceback.source})` : '';
    const times = traceback.count > 1 ? ` ×${traceback.count}` : '';
    lines.push(`  ${traceback.message}${where}${times}`);
    for (const frame of traceback.frames) {
      lines.push(`      ${frame}`);
    }
  }

  const hidden = tracebacks.length - shown.length;
  if (hidden > 0) {
    lines.push(`  ...and ${hidden} more distinct traceback(s)`);
  }

  return lines.join('\n');
}
