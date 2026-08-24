import { Brio } from '../../../../brio';
import { Maid } from '../../../../maid';
import { Observable } from '../../../../rx';
import { CameraState } from '../CameraState';
import { CameraEffect } from './CameraEffectUtils';

interface DefaultCamera extends CameraEffect {
  SetRobloxFieldOfView(fieldOfView: number): void;
  SetRobloxCameraState(state: CameraState): void;
  SetRobloxCFrame(cframe: CFrame): void;
  GetRobloxCameraState(): CameraState;
  SetLastSetDefaultCamera(DefaultCamera: DefaultCamera): void;
  IsFirstPerson(): boolean;
  ObserveIsFirstPerson(): Observable<boolean>;
  ObserveIsFirstPersonBrio(
    predicate?: (value: boolean) => boolean
  ): Observable<Brio<boolean>>;
  BindToRenderStep(): Maid;
  UnbindFromRenderStep(): void;
  Destroy(): void;
}

interface DefaultCameraConstructor {
  readonly ClassName: 'DefaultCamera';
  new (): DefaultCamera;
}

export const DefaultCamera: DefaultCameraConstructor;
