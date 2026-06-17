import { Brio } from '@quenty/brio';
import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { CheckType, ValueObject } from '@quenty/valueobject';
import { SpringObject } from './SpringObject';
import { Signal, SignalLike } from '@quenty/signal';

export type ToPropertyObservableArgument<T> =
  | Observable<T>
  | Promise<T>
  | {
      Observe(): T;
    }
  | ValueBase;

type BlendProps<T extends Instance> = {
  [K in keyof WritableInstanceProperties<T>]?:
    | WritableInstanceProperties<T>[K]
    | ToPropertyObservableArgument<WritableInstanceProperties<T>[K]>;
} & {
  __tags?: string[];
  __instance?: (instance: T) => void;
  __children?: Observable<Instance>[];
};

export namespace Blend {
  function New<T extends keyof CreatableInstances>(
    className: T
  ): (props: BlendProps<Instances[T]>) => Observable<Instances[T]>;
  const Tags: '__tags';
  const Instance: '__instance';
  const Children: '__children';
  function OnChange<T extends Instance>(
    propertyName: keyof InstanceProperties<T>
  ): symbol;
  function OnEvent<T extends Instance>(
    eventName: keyof InstanceEvents<T>
  ): symbol;
  function Attached<T extends Instance>(
    callback: (instance: T) => void
  ): symbol;
  function Find<T extends keyof Instances>(
    className: T
  ): (
    props: Instances[T] extends Instance ? BlendProps<Instances[T]> : never
  ) => symbol;
  function Single(
    observable: Observable<Instance | Brio<Instance>>
  ): Observable<Brio<Instance>>;
  function mount<T extends Instance>(instance: T, props: BlendProps<T>): Maid;

  function State<T = unknown>(
    defaultValue?: T,
    checkType?: CheckType
  ): ValueObject<T>;
  function Computed<T>(
    ...values: [...values: unknown[], compute: () => T]
  ): Observable<T>;
  function ComputedPairs<T>(
    value: unknown,
    compute: (key: unknown, value: unknown, maid: Maid) => T
  ): Observable<Brio<T>>;
  function AccelTween(
    source: unknown,
    acceleration: unknown
  ): Observable<number>;
  function Spring<T>(
    ...args: ConstructorParameters<typeof SpringObject<T>>
  ): Observable<SpringObject<T>>;
  function toPropertyObservable(
    value: ToPropertyObservableArgument<unknown>
  ): Observable | undefined;
  function toNumberObservable(
    value: number | ToPropertyObservableArgument<number>
  ): Observable<number>;
  function toEventObservable<
    T extends
      | Observable<unknown>
      | RBXScriptSignal<(...args: unknown[]) => unknown>
      | Signal<unknown>
  >(
    value: T
  ): T extends Observable<infer V>
    ? Observable<V>
    : T extends RBXScriptSignal<infer V>
    ? Observable<Parameters<V>>
    : T extends Signal<infer V>
    ? Observable<V>
    : never;
  function toEventHandler<
    T extends
      | ((...args: unknown[]) => unknown)
      | ValueBase
      | SignalLike<unknown>
      | ValueObject<unknown>
  >(
    value: T
  ): T extends (...args: infer V) => unknown
    ? (...args: V) => void
    : T extends ValueBase
    ? (result: unknown) => void
    : T extends SignalLike<infer V>
    ? (result: V) => void
    : T extends ValueObject<infer V>
    ? (result: V) => void
    : never;
  function Throtthled<T>(observable: Observable<T>): Observable<T>;
  function Shared<T>(observable: Observable<T>): Observable<T>;
  const Dynamic: typeof Computed;
}
