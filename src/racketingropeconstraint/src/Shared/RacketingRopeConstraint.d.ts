import { BaseObject } from '@quenty/baseobject';
import { Binder } from '@quenty/binder';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

interface BoundRacketingRopeConstraint extends BaseObject {
  PromiseConstrained(): Promise;
  ObserveIsConstrained(): Observable<boolean>;
}

interface BoundRacketingRopeConstraintConstructor {
  readonly ClassName: 'BoundRacketingRopeConstraint';
  new (
    ropeConstraint: RopeConstraint,
    serviceBag: ServiceBag
  ): BoundRacketingRopeConstraint;
}

export const BoundRacketingRopeConstraint: BoundRacketingRopeConstraintConstructor;

export const RacketingRopeConstraint: Binder<BoundRacketingRopeConstraint>;
