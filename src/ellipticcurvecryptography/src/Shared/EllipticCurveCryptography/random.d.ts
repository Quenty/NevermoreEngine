import { ByteTable } from '.';

export namespace random {
  function save(): void;
  function seed(data: unknown): void;
  function random(): ByteTable;
}
