type InstancesInheritingValueBase = {
  [K in keyof Instances]: Instances[K] extends ValueBase
    ? K extends 'ValueBase'
      ? never
      : K
    : never;
};

type ValueBaseType =
  InstancesInheritingValueBase[keyof InstancesInheritingValueBase];

export namespace ValueBaseUtils {
  function isValueBase(instance: Instance): instance is ValueBase;
  function getValueBaseType(
    valueBaseClassName: ValueBaseType
  ): string | undefined;
  function getClassNameFromType(luaType: string): ValueBaseType | undefined;
  function getOrCreateValue(
    parent: Instance,
    instanceType: ValueBaseType,
    name: string,
    defaultValue?: unknown
  ): Instance;
  function setValue(
    parent: Instance,
    instanceType: ValueBaseType,
    name: string,
    value: unknown
  ): void;
  function getValue<T = unknown>(
    parent: Instance,
    instanceType: ValueBaseType,
    name: string
  ): T | undefined;
  function getValue<T>(
    parent: Instance,
    instanceType: ValueBaseType,
    name: string,
    defaultValue: T
  ): T;
  function createGetSet<T = unknown>(
    instanceType: ValueBaseType,
    name: string
  ): LuaTuple<
    [
      getter: (parent: Instance, defaultValue?: T) => T | undefined,
      setter: (parent: Instance, value?: T) => T | undefined,
      initializer: (parent: Instance, defaultValue?: T) => T | undefined
    ]
  >;
}
