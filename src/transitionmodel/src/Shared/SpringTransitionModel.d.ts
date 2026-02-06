import { BasicPane } from '@quenty/basicpane';
import { Observable } from '@quenty/rx';
import { LinearValue } from '@quenty/spring';

type Target = LinearValue<number> | number;

interface SpringTransitionModel<T extends Target> extends BasicPane {
  SetShowTarget(target?: T, doNotAnimate?: boolean): void;
  SetHideTarget(target?: T, doNotAnimate?: boolean): void;
  IsShowingComplete(): boolean;
  IsHidingComplete(): boolean;
  ObserveIsShowingComplete(): Observable<boolean>;
  ObserveIsHidingComplete(): Observable<boolean>;
  BindToPaneVisibility(pane: BasicPane): () => void;
  GetVelocity(): T;
  SetSpeed(speed: number | Observable<T>): void;
  SetDamper(damper: number | Observable<T>): void;
  ObserveRenderStepped(): Observable<T>;
  Observe(): Observable<T>;
  PromiseShow(doNotAnimate?: boolean): Promise<void>;
  PromiseHide(doNotAnimate?: boolean): Promise<void>;
  PromiseToggle(doNotAnimate?: boolean): Promise<void>;
}

interface SpringTransitionModelConstructor {
  readonly ClassName: 'SpringTransitionModel';
  new (): SpringTransitionModel<number>;
  new <T extends Target>(
    showTarget?: T,
    hideTarget?: T
  ): SpringTransitionModel<T>;
}

export const SpringTransitionModel: SpringTransitionModelConstructor;
