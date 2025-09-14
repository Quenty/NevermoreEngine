import { Binder } from '@quenty/binder';

type BoundLinkCollection<T> = {
  GetClasses(): T[];
  HasClass(value: T): boolean;
  TrackParent(parent: Instance): void;
  Destroy(): void;
};

interface BoundLinkCollectionConstructor {
  readonly ClassName: 'BoundLinkCollection';
  new <T>(
    binder: Binder<T>,
    linkName: string,
    parent: Instance
  ): BoundLinkCollection<T>;

  DEAD: BoundLinkCollection;
}

export const BoundLinkCollection: BoundLinkCollectionConstructor;
