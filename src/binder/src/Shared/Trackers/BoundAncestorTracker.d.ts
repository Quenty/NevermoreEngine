import { BaseObject } from '@quenty/baseobject';
import { Binder } from '../Binder';
import { ValueObject } from '@quenty/valueobject';

interface BoundAncestorTracker<T> extends BaseObject {
  Class: ValueObject<T | undefined>;
}

interface BoundAncestorTrackerConstructor {
  readonly ClassName: 'BoundAncestorTracker';
  new <T>(binder: Binder<T>, child: Instance): BoundAncestorTracker<T>;
}

export const BoundAncestorTracker: BoundAncestorTrackerConstructor;
