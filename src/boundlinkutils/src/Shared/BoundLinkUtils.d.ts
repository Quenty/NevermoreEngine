import { Binder } from '@quenty/binder';

type FunctionPropertyNames<T> = {
  [K in keyof T]: T[K] extends (...args: any) => any ? K : never;
}[keyof T];

type FunctionPropertyType<
  T,
  K extends FunctionPropertyNames<T>
> = T[K] extends (...args: any) => any ? T[K] : never;

export namespace BoundLinkUtils {
  function getLinkClass<T>(
    binder: Binder<T>,
    linkName: string,
    from: Instance
  ): T | undefined;
  function getLinkClasses<T>(
    binder: Binder<T>,
    linkName: string,
    from: Instance
  ): T[];
  function getClassesForLinkValues<T extends Binder<unknown>[]>(
    binders: T,
    linkName: string,
    from: Instance
  ): (T[number] extends Binder<infer U> ? U : never)[];
  function callMethodOnLinkedClasses<
    T extends Binder<unknown>[],
    U = T[number] extends Binder<infer X> ? X : never,
    M extends FunctionPropertyNames<U> = FunctionPropertyNames<U>
  >(
    binders: T,
    linkName: string,
    from: Instance,
    methodName: M,
    ...args: Parameters<FunctionPropertyType<U, M>>
  ): void;
}
