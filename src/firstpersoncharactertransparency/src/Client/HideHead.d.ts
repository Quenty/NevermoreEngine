import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface HideHead extends BaseObject {}

interface HideHeadConstructor {
  readonly ClassName: 'HideHead';
  new (character: Model, serviceBag: ServiceBag): HideHead;
}

export const HideHead: HideHeadConstructor;
