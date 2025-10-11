import { chacha20 as chacha20ns } from './chacha20';
import { sha256 as sha256ns } from './sha256';
import { random as randomns } from './random';

export type ByteTable = number[] & {
  __brand: 'ByteTable';
} & {
  toHex(): string;
  isEqual(other: ByteTable): boolean;
};

export namespace EllipticCurveCryptography {
  const chacha20: typeof chacha20ns;
  const sha256: typeof sha256ns;
  const random: typeof randomns;
  function isByteTable(value: unknown): value is ByteTable;
  function createByteTable(value: number[]): ByteTable;
  function encrypt(data: string | ByteTable, key: ByteTable): ByteTable;
  function decrypt(data: string | ByteTable, key: ByteTable): ByteTable;
  function keypair(
    seed: number
  ): LuaTuple<[privateKey: ByteTable, publicKey: ByteTable]>;
  function exchange(privateKey: ByteTable, publicKey: ByteTable): ByteTable;
  function sign(privateKey: ByteTable, message: string | ByteTable): ByteTable;
  function verify(
    publicKey: ByteTable,
    message: string | ByteTable,
    signature: ByteTable
  ): boolean;
}
