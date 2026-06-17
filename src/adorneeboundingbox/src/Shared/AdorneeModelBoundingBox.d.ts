import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';

interface AdorneeModelBoundingBox extends BaseObject {
  ObserveCFrame(): Observable<CFrame>;
  ObserveSize(): Observable<Vector3>;
}

interface AdorneeModelBoundingBoxConstructor {
  readonly ClassName: 'AdorneeModelBoundingBox';
  new (model: Model): AdorneeModelBoundingBox;
}

export const AdorneeModelBoundingBox: AdorneeModelBoundingBoxConstructor;
