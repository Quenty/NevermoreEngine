import { RoguePropertyTable } from '../Implementation/RoguePropertyTable';

interface RoguePropertyCache<T> {
  Store(adornee: Instance, roguePropertyTable: RoguePropertyTable<T>): void;
  Find(adornee: Instance): RoguePropertyTable<T> | undefined;
}

interface RoguePropertyCacheConstructor {
  readonly ClassName: 'RoguePropertyCache';
  new <T = unknown>(): RoguePropertyCache<T>;
}

export const RoguePropertyCache: RoguePropertyCacheConstructor;
