import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';

interface BoundingBoxData {
  CFrame: CFrame;
  Size: Vector3;
}

interface AdorneeBoundingBox extends BaseObject {
  SetAdornee(adornee: Instance | undefined): () => void;
  ObserveBoundingBox(): Observable<BoundingBoxData>;
  GetBoundingBox(): BoundingBoxData | undefined;
  ObserveCFrame(): Observable<CFrame | undefined>;
  GetCFrame(): CFrame | undefined;
  ObserveSize(): Observable<Vector3 | undefined>;
  GetSize(): Vector3 | undefined;
}

interface AdorneeBoundingBoxConstructor {
  readonly ClassName: 'AdorneeBoundingBox';
  new (initialAdornee?: Instance): AdorneeBoundingBox;
}

export const AdorneeBoundingBox: AdorneeBoundingBoxConstructor;
