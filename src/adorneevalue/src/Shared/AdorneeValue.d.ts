import { Signal } from '@quenty/signal';
import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';

type AdorneeValueOption = Instance | CFrame | Vector3;

interface AdorneeValue extends BaseObject {
  Value: AdorneeValueOption | undefined;
  readonly Changed: Signal<
    [new: AdorneeValueOption | undefined, old: AdorneeValueOption | undefined]
  >;
  GetAdornee(): AdorneeValueOption | undefined;
  Observe(): Observable<AdorneeValueOption | undefined>;
  ObserveBottomCFrame(): Observable<CFrame | undefined>;
  ObserveCenterPosition(): Observable<Vector3 | undefined>;
  GetCenterPosition(): Vector3 | undefined;
  ObserveRadius(): Observable<number | undefined>;
  GetRadius(): number | undefined;
  ObservePositionTowards(
    observeTargetPosition: Observable<Vector3>,
    observeRadius?: Observable<number>
  ): Observable<Vector3 | undefined>;
  GetPositionTowards(
    target: Vector3,
    radius?: number,
    center?: Vector3
  ): Vector3 | undefined;
  ObserveAttachmentParent(): Observable<BasePart | Terrain | undefined>;
  RenderPositionAttachment(props?: { WorldPosition?: Vector3; Name?: string });
}

interface AdorneeValueConstructor {
  readonly ClassName: 'AdorneeValue';
  new (): AdorneeValue;
}

export const AdorneeValue: AdorneeValueConstructor;
