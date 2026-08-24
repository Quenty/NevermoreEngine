import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { ValueObject } from '@quenty/valueobject';

interface HandleHighlightModel extends BaseObject {
  IsMouseOver: ValueObject<boolean>;
  IsMouseDown: ValueObject<boolean>;
  IsHighlighted: ValueObject<boolean>;
  SetHandle(handle: HandleAdornment): void;
  ObservePercentPressed(): Observable<number>;
  ObservePercentHighlighted(): Observable<number>;
  ObservePercentHighlightedTarget(): Observable<number>;
}

interface HandleHighlightModelConstructor {
  readonly ClassName: 'HandleHighlightModel';
  new (parent?: Instance): HandleHighlightModel;
}

export const HandleHighlightModel: HandleHighlightModelConstructor;
