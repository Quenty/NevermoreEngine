import { BaseObject } from '@quenty/baseobject';
import { ValueObject } from '@quenty/valueobject';

interface GamepadRotateModel extends BaseObject {
  IsRotating: ValueObject<boolean>;
  SetAcceleration(acceleration: number): void;
  GetThumbstickDeltaAngle(): Vector2;
  StopRotate(): void;
  HandleThumbstickInput(input: Vector2): void;
}

interface GamepadRotateModelConstructor {
  readonly ClassName: 'GamepadRotateModel';
  new (): GamepadRotateModel;
}

export const GamepadRotateModel: GamepadRotateModelConstructor;
