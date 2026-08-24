import { Motor6DTransformer } from './Motor6DTransformer';

interface Motor6DSmoothTransformer extends Motor6DTransformer {
  SetSpeed(speed: number): void;
  SetTarget(target: number): void;
}

interface Motor6DSmoothTransformerConstructor {
  readonly ClassName: 'Motor6DSmoothTransformer';
  new (
    getTransform: (below: CFrame) => CFrame | undefined
  ): Motor6DSmoothTransformer;
}

export const Motor6DSmoothTransformer: Motor6DSmoothTransformerConstructor;
