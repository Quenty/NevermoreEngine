import * as zlib from 'zlib';

/**
 * Rewrite a binary place file's compressed chunks as long-window zstd.
 *
 * Every script's source lives in one `PROP` chunk per class, and Rojo and Lune
 * compress chunks as LZ4, whose 64 KB window cannot reach a module the place
 * already holds a copy of. A Nevermore place carries its dependencies by copy
 * — a combined batch place a copy per package — so the same modules repeat
 * many times over and LZ4 stores every one. zstd with a long window and
 * long-distance matching finds them: a 40-package batch place measured 38.3 MB
 * as LZ4 and 1.3 MB recompressed, and ran identically.
 *
 * The binary format picks the codec per chunk from its leading bytes, so this
 * changes how the file is stored, not what it holds. Chunk payloads are
 * decompressed and recompressed byte for byte; nothing is parsed.
 */

/** zstd frame magic; the format reads any other compressed payload as LZ4. */
const ZSTD_MAGIC = 0xfd2fb528;

const PLACE_MAGIC = Buffer.from('<roblox!', 'latin1');
const HEADER_LENGTH = 32;
const CHUNK_HEADER_LENGTH = 16;

/**
 * 2^27, zstd's default decoder window limit. A larger window would need the
 * decoder to opt in, and this is the size Roblox has been seen to decode.
 */
const WINDOW_LOG = 27;
/** Level 9 is within 15% of level 19's size here at a fourteenth of the time. */
const COMPRESSION_LEVEL = 9;

/**
 * `zstdCompressSync` landed in Node 22.15 / 23.8 and the installed typings
 * predate it, so it is looked up rather than imported.
 */
interface ZstdZlib {
  zstdCompressSync(
    buffer: Buffer,
    options: { params: Record<number, number> }
  ): Buffer;
  zstdDecompressSync(buffer: Buffer): Buffer;
  constants: Record<string, number>;
}

export type PlaceRecompressionResult =
  | { kind: 'recompressed'; data: Buffer; originalBytes: number }
  /** Not a binary place, or every compressed chunk is already zstd. */
  | { kind: 'unchanged'; data: Buffer }
  | { kind: 'unsupported'; data: Buffer; reason: string };

/** Whether this Node can recompress places at all. */
export function getZstdSupport():
  | { supported: true }
  | { supported: false; reason: string } {
  const z = zlib as unknown as Partial<ZstdZlib>;
  if (
    typeof z.zstdCompressSync === 'function' &&
    typeof z.zstdDecompressSync === 'function'
  ) {
    return { supported: true };
  }
  return {
    supported: false,
    reason: `Node ${process.version} has no zstd (needs 22.15+ or 23.8+)`,
  };
}

export function recompressPlace(data: Buffer): PlaceRecompressionResult {
  if (
    data.length < HEADER_LENGTH ||
    !data.subarray(0, PLACE_MAGIC.length).equals(PLACE_MAGIC)
  ) {
    // An XML place, or not a place: nothing to recompress.
    return { kind: 'unchanged', data };
  }

  const chunks = _readChunks(data);
  if (!chunks.some((c) => c.compressedLength > 0 && !c.isZstd)) {
    return { kind: 'unchanged', data };
  }

  const support = getZstdSupport();
  if (!support.supported) {
    return { kind: 'unsupported', data, reason: support.reason };
  }
  const z = zlib as unknown as ZstdZlib;
  const params = {
    [z.constants.ZSTD_c_compressionLevel]: COMPRESSION_LEVEL,
    [z.constants.ZSTD_c_windowLog]: WINDOW_LOG,
    [z.constants.ZSTD_c_enableLongDistanceMatching]: 1,
  };

  const parts: Buffer[] = [data.subarray(0, HEADER_LENGTH)];
  for (const chunk of chunks) {
    if (chunk.compressedLength === 0 || chunk.isZstd) {
      parts.push(data.subarray(chunk.start, chunk.end));
      continue;
    }

    const raw = decompressLz4Block(chunk.payload, chunk.uncompressedLength);
    const compressed = z.zstdCompressSync(raw, { params });

    const header = Buffer.from(
      data.subarray(chunk.start, chunk.start + CHUNK_HEADER_LENGTH)
    );
    header.writeUInt32LE(compressed.length, 4);
    parts.push(header, compressed);
  }

  return {
    kind: 'recompressed',
    data: Buffer.concat(parts),
    originalBytes: data.length,
  };
}

interface PlaceChunk {
  /** Offset of the chunk header. */
  start: number;
  /** Offset just past the payload. */
  end: number;
  compressedLength: number;
  uncompressedLength: number;
  payload: Buffer;
  isZstd: boolean;
}

function _readChunks(data: Buffer): PlaceChunk[] {
  const chunks: PlaceChunk[] = [];
  let pos = HEADER_LENGTH;
  let sawEnd = false;

  while (!sawEnd) {
    if (pos + CHUNK_HEADER_LENGTH > data.length) {
      throw new Error('Place file is truncated before its END chunk');
    }

    const name = data.toString('latin1', pos, pos + 4);
    const compressedLength = data.readUInt32LE(pos + 4);
    const uncompressedLength = data.readUInt32LE(pos + 8);
    const payloadStart = pos + CHUNK_HEADER_LENGTH;
    const end = payloadStart + (compressedLength || uncompressedLength);
    if (end > data.length) {
      throw new Error(
        `Place file is truncated inside its ${name.trim()} chunk`
      );
    }

    const payload = data.subarray(payloadStart, end);
    chunks.push({
      start: pos,
      end,
      compressedLength,
      uncompressedLength,
      payload,
      isZstd: compressedLength >= 4 && payload.readUInt32LE(0) === ZSTD_MAGIC,
    });

    pos = end;
    sawEnd = name === 'END\0';
  }

  // Anything after END is not the format's, but it is kept rather than dropped.
  if (pos < data.length) {
    chunks.push({
      start: pos,
      end: data.length,
      compressedLength: 0,
      uncompressedLength: data.length - pos,
      payload: data.subarray(pos),
      isZstd: false,
    });
  }

  return chunks;
}

/** Decode one raw LZ4 block, the format's default chunk compression. */
export function decompressLz4Block(
  src: Buffer,
  uncompressedLength: number
): Buffer {
  const out = Buffer.alloc(uncompressedLength);
  let s = 0;
  let d = 0;

  while (s < src.length) {
    const token = src[s++]!;

    let literalLength = token >> 4;
    if (literalLength === 15) {
      let b: number;
      do {
        b = src[s++]!;
        literalLength += b;
      } while (b === 255);
    }
    src.copy(out, d, s, s + literalLength);
    s += literalLength;
    d += literalLength;

    // The last sequence is literals only.
    if (s >= src.length) break;

    const offset = src[s]! | (src[s + 1]! << 8);
    s += 2;
    if (offset === 0 || offset > d) {
      throw new Error('Corrupt LZ4 block: match offset out of range');
    }

    let matchLength = token & 15;
    if (matchLength === 15) {
      let b: number;
      do {
        b = src[s++]!;
        matchLength += b;
      } while (b === 255);
    }
    matchLength += 4;

    // Byte by byte: a match may overlap the bytes it is producing.
    for (let i = 0; i < matchLength; i++) {
      out[d] = out[d - offset]!;
      d++;
    }
  }

  if (d !== uncompressedLength) {
    throw new Error(
      `Corrupt LZ4 block: decoded ${d} bytes, expected ${uncompressedLength}`
    );
  }
  return out;
}
