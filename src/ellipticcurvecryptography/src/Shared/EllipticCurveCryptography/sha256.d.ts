import { ByteTable } from '.';

export namespace sha256 {
  function digest(data: string | ByteTable): ByteTable;
  function hmac(data: string | ByteTable, key: string | ByteTable): ByteTable;
  function pbkdf2(
    pass: string | ByteTable,
    salt: string | ByteTable,
    iter: number,
    dklen?: number
  ): ByteTable;
}
