import * as zlib from 'zlib';
import { describe, it, expect } from 'vitest';
import {
  decompressLz4Block,
  getZstdSupport,
  recompressPlace,
} from './place-recompression.js';

const zstd = zlib as unknown as { zstdDecompressSync(b: Buffer): Buffer };

/** "abcd", then 8 bytes copied from 4 back (overlapping), then "xy". */
const LZ4_BLOCK = Buffer.concat([
  Buffer.from([0x44]),
  Buffer.from('abcd'),
  Buffer.from([0x04, 0x00]),
  Buffer.from([0x20]),
  Buffer.from('xy'),
]);
const LZ4_DECODED = 'abcdabcdabcdxy';

function chunk(
  name: string,
  payload: Buffer,
  uncompressedLength: number,
  compressed: boolean
) {
  const header = Buffer.alloc(16);
  header.write(name, 0, 'latin1');
  header.writeUInt32LE(compressed ? payload.length : 0, 4);
  header.writeUInt32LE(uncompressedLength, 8);
  return Buffer.concat([header, payload]);
}

function place(...chunks: Buffer[]) {
  const header = Buffer.alloc(32);
  header.write('<roblox!', 0, 'latin1');
  return Buffer.concat([header, ...chunks]);
}

const END = chunk('END\0', Buffer.from('</roblox>'), 9, false);

describe('decompressLz4Block', () => {
  it('decodes literals and an overlapping match', () => {
    expect(decompressLz4Block(LZ4_BLOCK, LZ4_DECODED.length).toString()).toBe(
      LZ4_DECODED
    );
  });

  it('rejects a block that decodes to the wrong length', () => {
    expect(() => decompressLz4Block(LZ4_BLOCK, LZ4_DECODED.length + 1)).toThrow(
      /expected/
    );
  });

  it('rejects a match reaching before the start of the output', () => {
    const bad = Buffer.from([0x14, 0x61, 0x09, 0x00, 0x00]);
    expect(() => decompressLz4Block(bad, 13)).toThrow(/offset/);
  });
});

describe.runIf(getZstdSupport().supported)('recompressPlace', () => {
  it('rewrites LZ4 chunks as zstd holding the same bytes, and keeps the rest', () => {
    const original = place(
      chunk('PROP', LZ4_BLOCK, LZ4_DECODED.length, true),
      END
    );

    const result = recompressPlace(original);
    expect(result.kind).toBe('recompressed');

    const data = result.data;
    expect(data.subarray(0, 32)).toEqual(original.subarray(0, 32));
    expect(data.toString('latin1', 32, 36)).toBe('PROP');

    const compressedLength = data.readUInt32LE(36);
    expect(data.readUInt32LE(40)).toBe(LZ4_DECODED.length);
    const payload = data.subarray(48, 48 + compressedLength);
    expect(payload.readUInt32LE(0)).toBe(0xfd2fb528);
    expect(zstd.zstdDecompressSync(payload).toString()).toBe(LZ4_DECODED);

    // END is uncompressed, so it comes through untouched.
    expect(data.subarray(48 + compressedLength)).toEqual(END);
  });

  it('leaves a place with nothing left to recompress alone', () => {
    const once = recompressPlace(
      place(chunk('PROP', LZ4_BLOCK, LZ4_DECODED.length, true), END)
    ).data;

    expect(recompressPlace(once)).toEqual({ kind: 'unchanged', data: once });
  });

  it('leaves files that are not binary places alone', () => {
    const xml = Buffer.from('<roblox version="4"></roblox>');
    expect(recompressPlace(xml)).toEqual({ kind: 'unchanged', data: xml });
  });

  it('refuses a truncated place rather than uploading part of it', () => {
    const truncated = place(
      chunk('PROP', LZ4_BLOCK, LZ4_DECODED.length, true)
    ).subarray(0, 40);
    expect(() => recompressPlace(truncated)).toThrow(/truncated/);
  });
});
