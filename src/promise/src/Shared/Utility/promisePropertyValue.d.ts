export const promisePropertyValue: <
  T extends Instance,
  V extends keyof InstanceProperties<T>
>(
  instance: T,
  propertyName: V
) => Promise<InstanceProperties<T>[V]>;
