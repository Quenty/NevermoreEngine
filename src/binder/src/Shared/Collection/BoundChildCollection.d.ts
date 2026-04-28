import { BaseObject } from '@quenty/baseobject';
import { Binder } from '../Binder';
import { Signal } from '@quenty/signal';

interface BoundChildCollection<T> extends BaseObject {
  ClassAdded: Signal<T>;
  ClassRemoved: Signal<T>;

  HasClass(classObj: T): boolean;
  GetSize(): number;
  GetSet(): ReadonlyMap<T, true>;
  GetClasses(): T[];
}

interface BoundChildCollectionConstructor {
  readonly ClassName: 'BoundChildCollection';
  new <T>(binder: Binder<T>): BoundChildCollection<T>;

  readonly ExtraPixels: 2;
}

export const BoundChildCollection: BoundChildCollectionConstructor;
