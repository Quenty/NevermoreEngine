import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';

interface GameScalingHelper extends BaseObject {
  ObserveIsSmall(): Observable<boolean>;
  ObserveIsVertical(): Observable<boolean>;
  GetAbsoluteSizeSetter(): (absoluteSize: Vector2) => void;
  SetAbsoluteSize(absoluteSize: Vector2 | Observable<Vector2>): void;
  SetScreenGui(screenGui: ScreenGui): () => void;
}

interface GameScalingHelperConstructor {
  readonly ClassName: 'GameScalingHelper';
  new (screenGui: ScreenGui): GameScalingHelper;
}

export const GameScalingHelper: GameScalingHelperConstructor;
