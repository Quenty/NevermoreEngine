import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

interface Binder<T> {
  Init(): void;
  Start(): void;
  GetTag(): string;
  GetConstructor(): new () => T;
  ObserveAllBrio(): Observable<[Brio<[T]>]>;
  ObserveBrio(instance: Instance): Observable<[Brio<[T]>]>;
  ObserveInstance(
    instance: Instance,
    callback: (boundClass: T) => void
  ): () => void;
  GetClassAddedSignal(): Signal<[T]>;
  GetClassRemovingSignal(): Signal<[T]>;
  GetClassRemovedSignal(): Signal<[T]>;
  GetAll(): T[];
  GetAllSet(): ReadonlyMap<T, true>;
  Bind(instance: Instance): T?;
  Tag(instance: Instance): void;
  HasTag(instance: Instance): boolean;
  Untag(instance: Instance): void;
  Unbind(instance: Instance): void;
  BindClient(instance: Instance): T?;
  UnbindClient(instance: Instance): void;
  Get(instance: Instance): T?;
  Promise(instance: Instance, cancelToken: CancelToken?): Promise<T>;
  Create(className: string?): Instance;
  Observe(instance: Instance): Observable<[T]>;
  Destroy(): void;
}

interface BinderConstructor {
  readonly ClassName: 'Binder';

  isBinder: (value: any) => value is Binder<unknown>;

  new <T>(
    tagName: string,
    constructor: new () => T,
    ...args: unknown[]
  ): Binder<T>;
}

export const Binder: BinderConstructor;
