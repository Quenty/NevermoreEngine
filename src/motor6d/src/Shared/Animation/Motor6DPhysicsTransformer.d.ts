import { Motor6DTransformer } from './Motor6DTransformer';

interface Motor6DPhysicsTransformer extends Motor6DTransformer {
  SetSpeed(speed: number): void;
}

interface Motor6DPhysicsTransformerConstructor {
  readonly ClassName: 'Motor6DPhysicsTransformer';
  new (physicsTransform: CFrame): Motor6DPhysicsTransformer;
}

export const Motor6DPhysicsTransformer: Motor6DPhysicsTransformerConstructor;
