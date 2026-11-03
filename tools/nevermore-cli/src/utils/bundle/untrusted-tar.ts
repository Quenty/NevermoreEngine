import { createReadStream, createWriteStream } from 'fs';
import * as path from 'path';
import * as tar from 'tar';

// Names reach the bot's PR comment, so a fork's bundle gets no Markdown links,
// images, URLs, tables or @mentions: only a leading scope `@`, and plain text
// for a multi-place target's place name ("pkg - Hub (Test)").
export const PACKAGE_NAME_PATTERN = /^@?[\p{L}\p{N} /()+.,'_~-]{1,200}$/u;

export type BundleKind = 'tests' | 'deploy';

const RUN_COMMANDS: Record<BundleKind, string> = {
  tests: 'nevermore batch test --bundle <file>',
  deploy: 'nevermore batch deploy --bundle <file>',
};

export interface UntrustedTarOptions {
  kind: BundleKind;
  /** The one entry read into memory rather than written to `dir`. */
  manifestName: string;
  maxManifestBytes: number;
  /** Every other entry must pass this, by its exact path in the archive. */
  isEntryAllowed: (name: string) => boolean;
  maxEntries: number;
  /** Message for an archive holding more than `maxEntries` entries. */
  maxEntriesMessage: string;
  /** Returns an error message when `size` is too large for this entry. */
  checkEntrySize: (name: string, size: number) => string | undefined;
}

export interface UntrustedTarContents {
  manifestText: string;
  /** Size of each entry written into `dir`, keyed by its archive path. */
  entrySizes: Map<string, number>;
}

/**
 * Read a bundle written by a fork's CI run into `dir`. Entries are read from the
 * archive, never extracted by it: only regular files whose paths match
 * `entryPattern` (or are the manifest) are accepted, so a path can never leave
 * `dir` and a link can never be followed.
 */
export async function readUntrustedTarAsync(
  file: string,
  dir: string,
  options: UntrustedTarOptions
): Promise<UntrustedTarContents> {
  let manifestText: string | undefined;
  const entrySizes = new Map<string, number>();
  const writes: Promise<void>[] = [];
  let failure: Error | undefined;
  // Write errors are recorded rather than rejected: the promises are awaited
  // only once parsing ends, and one rejecting before then is unhandled.
  const fail = (err: Error) => {
    failure ??= err;
  };

  const parser = new tar.Parser({
    strict: true,
    onReadEntry: (entry) => {
      const name = entry.path;
      const reject = (message: string) => {
        failure ??= new Error(message);
        entry.resume();
      };

      if (entry.type !== 'File' && entry.type !== 'OldFile') {
        return reject(`Bundle entry ${name} is not a regular file`);
      }

      if (name === options.manifestName) {
        if (
          manifestText !== undefined ||
          entry.size > options.maxManifestBytes
        ) {
          return reject('Bundle has more than one manifest, or one too large');
        }
        const parts: Buffer[] = [];
        entry.on('data', (part: Buffer) => parts.push(part));
        entry.on('end', () => {
          manifestText = Buffer.concat(parts).toString('utf-8');
        });
        return;
      }

      if (!options.isEntryAllowed(name) || entrySizes.has(name)) {
        return reject(`Bundle has an unexpected entry: ${name}`);
      }
      if (entrySizes.size >= options.maxEntries) {
        return reject(options.maxEntriesMessage);
      }
      const sizeError = options.checkEntrySize(name, entry.size);
      if (sizeError) {
        return reject(sizeError);
      }
      entrySizes.set(name, entry.size);
      writes.push(
        new Promise<void>((resolve) => {
          const done = (err?: Error) => {
            if (err) {
              fail(err);
            }
            resolve();
          };
          const out = createWriteStream(path.join(dir, name));
          out.on('finish', () => done());
          out.on('error', (err) => {
            done(err);
            entry.resume();
          });
          entry.on('error', (err: unknown) =>
            done(err instanceof Error ? err : new Error(String(err)))
          );
          entry.pipe(out);
        })
      );
    },
  });

  await new Promise<void>((resolve, rejectRead) => {
    const input = createReadStream(file);
    input.on('error', rejectRead);
    parser.on('error', (err: Error) =>
      rejectRead(new Error(`Bundle is not a valid tar file: ${err.message}`))
    );
    parser.on('end', () => resolve());
    input.pipe(parser);
  });
  await Promise.all(writes);

  _checkKind(manifestText, options.kind);
  if (failure) {
    throw failure;
  }
  if (manifestText === undefined) {
    throw new Error(`Bundle is missing ${options.manifestName}`);
  }
  return { manifestText, entrySizes };
}

function _checkKind(manifestText: string | undefined, expected: BundleKind) {
  if (manifestText === undefined) {
    return;
  }
  let kind: unknown;
  try {
    kind = (JSON.parse(manifestText) as { kind?: unknown })?.kind;
  } catch {
    return;
  }
  if (kind === undefined || kind === expected) {
    return;
  }
  if (kind === 'tests' || kind === 'deploy') {
    throw new Error(
      `This is a ${kind} bundle, not a ${expected} bundle. Run it with "${RUN_COMMANDS[kind]}".`
    );
  }
  throw new Error(`Bundle is of an unknown kind (expected ${expected})`);
}
