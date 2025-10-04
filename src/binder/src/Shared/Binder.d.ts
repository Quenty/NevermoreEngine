import { Signal } from '@quenty/signal';
import { Brio } from '../../../brio';
import { CancelToken } from '../../../canceltoken';
import { Observable } from '../../../rx';

interface Static {
  readonly ClassName: 'Binder';
}

export interface Binder<T> extends Static {
  readonly ServiceName: string;
  Init(): void;
  Start(): void;
  GetTag(): string;
  GetConstructor(): new (instance: Instance, ...args: unknown[]) => T;
  ObserveAllBrio(): Observable<Brio<T>>;
  ObserveBrio(instance: Instance): Observable<Brio<T>>;
  ObserveInstance(
    instance: Instance,
    callback: (boundClass: T) => void
  ): () => void;
  GetClassAddedSignal(): Signal<T>;
  GetClassRemovingSignal(): Signal<T>;
  GetClassRemovedSignal(): Signal<T>;
  GetAll(): T[];
  GetAllSet(): ReadonlyMap<T, true>;
  Bind(instance: Instance): T | undefined;
  Tag(instance: Instance): void;
  HasTag(instance: Instance): boolean;
  Untag(instance: Instance): void;
  Unbind(instance: Instance): void;
  BindClient(instance: Instance): T | undefined;
  UnbindClient(instance: Instance): void;
  Get(instance: Instance): T | undefined;
  Promise(instance: Instance, cancelToken?: CancelToken): Promise<T>;
  Create(className?: string): Instance;
  Observe(instance: Instance): Observable<T>;
  Destroy(): void;
}

interface BinderConstructor extends Static {
  isBinder: (value: unknown) => value is Binder<unknown>;

  new <TClass, TArgs extends unknown[], I extends Instance>(
    tagName: string,
    constructor: new (instance: I, ...args: TArgs) => TClass,
    ...args: TArgs
  ): Binder<TClass>;
}

export const Binder: BinderConstructor;

export {};
