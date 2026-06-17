import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface ShowBody extends BaseObject {}

interface ShowBodyConstructor {
  readonly ClassName: 'ShowBody';
  new (character: Model, serviceBag: ServiceBag): ShowBody;
}

export const ShowBody: ShowBodyConstructor;
