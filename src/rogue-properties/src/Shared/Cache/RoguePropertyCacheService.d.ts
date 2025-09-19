import { ServiceBag } from '@quenty/servicebag';
import { RoguePropertyDefinition } from '../Definition/RoguePropertyDefinition';
import { RoguePropertyCache } from './RoguePropertyCache';

export interface RoguePropertyCacheService {
  Init(serviceBag: ServiceBag): void;
  GetCache<T>(
    roguePropertyDefinition: RoguePropertyDefinition<T>
  ): RoguePropertyCache<T>;
}
