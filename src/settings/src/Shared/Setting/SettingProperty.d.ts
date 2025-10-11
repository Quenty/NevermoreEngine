import { ServiceBag } from '@quenty/servicebag';
import { SettingDefinition } from './SettingDefinition';
import { Signal } from '@quenty/signal';
import { Observable } from '@quenty/rx';
import { Promise } from '@quenty/promise';

interface SettingProperty<T> {
  Value: T;
  readonly Changed: Signal<T>;
  readonly DefaultValue: T;
  Observe(): Observable<T>;
  SetValue(value: T): void;
  PromiseValue(): Promise<T>;
  PromiseSetValue(value: T): Promise;
  RestoreDefault(): void;
  PromiseRestoreDefault(): Promise;
}

interface SettingPropertyConstructor {
  readonly ClassName: 'SettingProperty';
  new <T>(
    serviceBag: ServiceBag,
    player: Player,
    definition: SettingDefinition<T>
  ): SettingProperty<T>;
}

export const SettingProperty: SettingPropertyConstructor;
