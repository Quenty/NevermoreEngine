import { ServiceBag } from '@quenty/servicebag';
import { SettingDefinition } from './SettingDefinition';

type ToValueMap<
  T extends Record<string, SettingDefinition<unknown> | NonNullable<unknown>>
> = {
  [K in keyof T]: T[K] extends SettingDefinition<infer U>
    ? U
    : T[K] extends NonNullable<infer V>
    ? V
    : never;
};

type SettingDefinitionProvider<
  T extends Record<string, SettingDefinition<unknown> | NonNullable<unknown>>
> = {
  [K in keyof T]: SettingDefinition<ToValueMap<T>[K]>;
} & {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetSettingDefinitions(): {
    [K in keyof T]: SettingDefinition<ToValueMap<T>[K]>;
  };
  Get<K extends keyof T>(settingName: K): SettingDefinition<ToValueMap<T>[K]>;
  Destroy(): void;
};

interface SettingDefinitionProviderConstructor {
  readonly ClassName: 'SettingDefinitionProvider';
  readonly ServiceName: 'SettingDefinitionProvider';
  new <
    T extends Record<string, SettingDefinition<unknown> | NonNullable<unknown>>
  >(
    settingDefinitions: T
  ): SettingDefinitionProvider<T>;
}

export const SettingDefinitionProvider: SettingDefinitionProviderConstructor;
