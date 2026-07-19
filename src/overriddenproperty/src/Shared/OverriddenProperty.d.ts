import { BaseObject } from '@quenty/baseobject';

interface OverriddenProperty<V> extends BaseObject {
  Set(value: V): void;
  Get(): V;
}

interface OverriddenPropertyConstructor {
  readonly ClassName: 'OverriddenProperty';
  new <T extends Instance, V extends keyof WritableInstanceProperties<T>>(
    instance: T,
    propertyName: V
  ): OverriddenProperty<V>;
  new <T extends Instance, V extends keyof WritableInstanceProperties<T>>(
    instance: Instance,
    propertyName: string,
    replicateRate: number,
    replicateCallback: () => void
  ): OverriddenProperty<V>;
}

export const OverriddenProperty: OverriddenPropertyConstructor;
