import { BaseObject } from '../../../baseobject';

interface ApplyTagToTaggedChildren extends BaseObject {}

interface BrioConstructor {
  readonly ClassName: 'ApplyTagToTaggedChildren';
  new (
    parent: Instance,
    tag: string,
    requiredTag: string
  ): ApplyTagToTaggedChildren;
}

export const ApplyTagToTaggedChildren: BrioConstructor;
