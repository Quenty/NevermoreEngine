interface LRUCache {
  get(key: unknown): unknown;
  set(key: unknown, value: unknown, bytes?: number): void;
  delete(key: unknown): void;
  pairs(): IterableFunction<LuaTuple<[key: unknown, value: unknown]>>;
}

interface LRUCacheConstructor {
  readonly ClassName: 'LRUCache';
  new (maxSize: number, maxBytes?: number): LRUCache;
}

export const LRUCache: LRUCacheConstructor;
