export namespace UTF8 {
  const UPPER_MAP: Readonly<Record<string, string>>;
  const LOWER_MAP: Readonly<Record<string, string>>;

  function upper(str: string): string;
  function lower(str: string): string;
}
