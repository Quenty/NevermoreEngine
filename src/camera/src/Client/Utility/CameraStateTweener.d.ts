import { ServiceBag } from '../../../../servicebag';
import { CameraStack } from '../CameraStack';
import { CameraEffect, CameraLike } from '../Effects/CameraEffectUtils';

type CameraStateTweener = {
  getPercentVisible(): number;
  Show(doNotAnimate?: boolean): void;
  Hide(doNotAnimate?: boolean): void;
  IsFinishedHiding(): boolean;
  IsFinishedShowing(): boolean;
  Finish(doNotAnimate: boolean | undefined, callback: () => void): void;
  GetCameraEffect(): CameraEffect;
  GetCameraBelow(): CameraEffect;
  SetTarget(target: number, doNotAnimate?: boolean): void;
  SetSpeed(speed: number): void;
  SetVisible(isVisible: boolean, doNotAnimate?: boolean): void;
  GetFader(): CameraEffect;
};

interface CameraStateTweenerConstructor {
  readonly ClassName: 'CameraStateTweener';
  new (
    serviceBagOrCameraStack: ServiceBag | CameraStack,
    cameraEffect: CameraLike,
    speed?: number
  ): CameraStateTweener;
}

export const CameraStateTweener: CameraStateTweenerConstructor;
