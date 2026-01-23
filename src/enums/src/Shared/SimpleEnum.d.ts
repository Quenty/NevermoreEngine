type SimpleEnum<T> = T & {
  GetKeys(): (keyof T)[];
  GetValues(): T[keyof T][];
  GetMap(): Readonly<T>;
  IsValue(value: string): value is T[keyof T];
  GetInterface(): (value: unknown) => value is T[keyof T];
} & IterableFunction<LuaTuple<[keyof T, T[keyof T]]>>;

interface SimpleEnumConstructor {
  readonly ClassName: 'SimpleEnum';
  new <T extends Record<string, string>>(entries: T): SimpleEnum<T>;
}

export const SimpleEnum: SimpleEnumConstructor;
