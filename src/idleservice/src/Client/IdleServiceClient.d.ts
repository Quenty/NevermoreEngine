import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface IdleServiceClient {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  ObserveHumanoidMoveFromCurrentPosition(
    minimumTimeVisible: number
  ): Observable<Vector3>;
  IsHumanoidIdle(): boolean;
  IsMoving(): boolean;
  ObserveHumanoidIdle(): Observable<boolean>;
  DoShowIdleUI(): boolean;
  ObserveShowIdleUI(): Observable<boolean>;
  GetShowIdleUIBoolValue(): BoolValue;
  PushDisable(): () => void;
  Destroy(): void;
}
