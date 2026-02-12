import { BaseObject } from '@quenty/baseobject';
import { Binder } from '../Binder';
import { ValueObject } from '@quenty/valueobject';

interface BoundParentTracker<T> extends BaseObject {
  Class: ValueObject<T | undefined>;
}

interface BoundParentTrackerConstructor {
  readonly ClassName: 'BoundParentTracker';
  new <T>(binder: Binder<T>, child: Instance): BoundParentTracker<T>;
}

export const BoundParentTracker: BoundParentTrackerConstructor;
