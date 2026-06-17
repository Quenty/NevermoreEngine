export interface CacheConfig {
  maxSize: number;
}

export namespace MemorizeUtils {
  function memoize<T extends unknown[], R>(
    func: (...args: T) => R,
    cacheConfig?: CacheConfig
  ): (...args: T) => R;
  function isCacheConfig(value: unknown): value is CacheConfig;
  function createCacheConfig(cacheConfig?: CacheConfig): CacheConfig;
}
