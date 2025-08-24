import { BaseObject } from '../../../baseobject';
import { Observable } from '../../../rx';
import { Signal } from '../../../signal/src/Shared/Signal';

interface InputObjectTracker extends BaseObject {
  InputEnded: Signal;
  ObserveInputEnded(): Observable;
  GetInitialPosition(): Vector2;
  GetPosition(): Vector2;
  GetRay(rayDistance?: number): Ray;
  SetCamera(camera: Camera): void;
}

interface InputObjectTrackerConstructor {
  readonly ClassName: 'InputObjectTracker';
  new (initialInputObject: InputObject): InputObjectTracker;
}

export const InputObjectTracker: InputObjectTrackerConstructor;
