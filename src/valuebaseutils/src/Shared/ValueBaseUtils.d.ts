export type ValueBaseType =
  | 'BoolValue'
  | 'NumberValue'
  | 'IntValue'
  | 'StringValue'
  | 'BrickColorValue'
  | 'CFrameValue'
  | 'Color3Value'
  | 'ObjectValue'
  | 'RayValue'
  | 'Vector3Value';

export namespace ValueBaseUtils {
  function isValueBase(instance: Instance): instance is ValueBase;
  function getValueBaseType(valueBaseClassName: string): string | undefined;
  function getClassNameFromType(luaType: string): string | undefined;
  function getOrCreateValue(
    parent: Instance,
    instanceType: string,
    name: string,
    defaultValue?: unknown
  ): Instance;
  function setValue(
    parent: Instance,
    instanceType: string,
    name: string,
    value: unknown
  ): void;
  function getValue<T = unknown>(
    parent: Instance,
    instanceType: string,
    name: string
  ): T | undefined;
  function getValue<T>(
    parent: Instance,
    instanceType: string,
    name: string,
    defaultValue: T
  ): T;
  function createGetSet<T = unknown>(
    instanceType: string,
    name: string
  ): LuaTuple<
    [
      getter: (parent: Instance, defaultValue?: T) => T | undefined,
      setter: (parent: Instance, value?: T) => T | undefined,
      initializer: (parent: Instance, defaultValue?: T) => T | undefined
    ]
  >;
}
