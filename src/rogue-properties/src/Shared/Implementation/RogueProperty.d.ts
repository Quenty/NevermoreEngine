import { ServiceBag } from '@quenty/servicebag';
import { RoguePropertyDefinition } from '../Definition/RoguePropertyDefinition';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface RogueProperty<T> {
  Value: T;
  readonly Changed: Signal<T>;

  SetCanInitialize(canInitialize: boolean): void;
  GetAdornee(): Instance;
  CanInitialize(): boolean;
  GetBaseValueObject(): ValueBase;
  SetBaseValue(value: T): void;
  SetValue(value: T): void;
  GetBaseValue(): T;
  GetValue(): T;
  GetDefinition(): RoguePropertyDefinition<T>;
  GetRogueModifiers(): unknown; // not sure what this should be
  Observe(): Observable<T>;
  ObserveBrio(predicate?: (value: T) => boolean): Observable<T>;
  CreateMultiplier(amount: number, source?: Instance): ValueBase | undefined;
  CreateAdditive(amount: number, source?: Instance): ValueBase | undefined;
  GetNamedAdditive(name: string, source?: Instance): ValueBase | undefined;
  CreateSetter(value: T, source?: Instance): ValueBase | undefined;
  GetChangedEvent(): Signal<T>;
}

interface RoguePropertyConstructor {
  readonly ClassName: 'RogueProperty';
  new <T>(
    adornee: Instance,
    serviceBag: ServiceBag,
    definition: RoguePropertyDefinition<T>
  ): RogueProperty<T>;
}

export const RogueProperty: RoguePropertyConstructor;
