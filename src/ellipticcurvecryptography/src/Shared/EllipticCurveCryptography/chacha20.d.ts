import { ByteTable } from '.';

export namespace chacha20 {
  function crypt(
    data: string | ByteTable,
    key: ByteTable,
    nonce: ByteTable,
    cntr?: number,
    round?: number
  ): ByteTable;
}
