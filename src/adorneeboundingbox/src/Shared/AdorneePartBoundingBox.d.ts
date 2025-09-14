import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';

interface AdorneePartBoundingBox extends BaseObject {
  ObserveCFrame(): Observable<CFrame>;
  ObserveSize(): Observable<Vector3>;
}

interface AdorneePartBoundingBoxConstructor {
  readonly ClassName: 'AdorneePartBoundingBox';
  new (part: BasePart): AdorneePartBoundingBox;
}

export const AdorneePartBoundingBox: AdorneePartBoundingBoxConstructor;
