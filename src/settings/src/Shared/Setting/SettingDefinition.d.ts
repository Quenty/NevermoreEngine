import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { SettingProperty } from './SettingProperty';

interface SettingDefinition<T> {
  Init(serviceBag: ServiceBag): void;
  Get(player: Player): T;
  Set(player: Player, value: T): void;
  Promise(player: Player): Promise<T>;
  PromiseSet(player: Player, value: T): Promise;
  Observe(player: Player): Observable<T>;
  GetSettingProperty(
    serviceBag: ServiceBag,
    player?: Player
  ): SettingProperty<T>;
  GetLocalPlayerSettingProperty(serviceBag: ServiceBag): SettingProperty<T>;
  GetSettingName(): string;
  GetDefaultValue(): T;
  Destroy(): void;
}

interface SettingDefinitionConstructor {
  readonly ClassName: 'SettingDefinition';
  readonly ServiceName: 'SettingDefinition';
  new <T>(
    settingName: string,
    defaultValue: NonNullable<T>
  ): SettingDefinition<T>;

  isSettingDefinition: (value: unknown) => value is SettingDefinition<unknown>;
}

export const SettingDefinition: SettingDefinitionConstructor;
