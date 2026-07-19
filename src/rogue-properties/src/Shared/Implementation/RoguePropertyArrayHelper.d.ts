import { ServiceBag } from '@quenty/servicebag';
import { RoguePropertyDefinitionArrayHelper } from '../Definition/RoguePropertyDefinitionArrayHelper';
import { RoguePropertyTable, ToRogueProperties } from './RoguePropertyTable';
import { Observable } from '@quenty/rx';

interface RoguePropertyArrayHelper<T extends unknown[]> {
  SetCanInitialize(canInitialize: boolean): void;
  GetArrayRogueProperty<K extends number>(index: K): ToRogueProperties<T>[K];
  GetArrayRogueProperties(): ToRogueProperties<T>;
  SetArrayBaseData(arrayData: T): void;
  SetArrayData(arrayData: T): void;
  GetArrayBaseValues(): T;
  GetArrayValues(): T;
  ObserveArrayValues(): Observable<T>;
}

interface RoguePropertyArrayHelperConstructor {
  readonly ClassName: 'RoguePropertyArrayHelper';
  new <T extends unknown[]>(
    serviceBag: ServiceBag,
    arrayDefinitionHelper: RoguePropertyDefinitionArrayHelper,
    roguePropertyTable: RoguePropertyTable<T>
  ): RoguePropertyArrayHelper<T>;
}

export const RoguePropertyArrayHelper: RoguePropertyArrayHelperConstructor;
