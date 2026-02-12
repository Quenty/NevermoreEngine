import { ServiceBag } from '@quenty/servicebag';

export interface Particle {
  Position: Vector3;
  Global: boolean;
  Velocity: Vector3;
  Gravity: Vector3;
  WindResistance: number;
  LifeTime: number;
  Size: Vector2;
  Bloom: Vector2;
  Transparency: number;
  Color: Color3;
  Occlusion?: boolean;
  RemoveOnCollision?: (
    particle: Particle,
    hit: BasePart,
    position: Vector3,
    normal: Vector3,
    material: Enum.Material
  ) => boolean;
  Function?: (particle: Particle, dt: number, t: number) => void;
}

export interface ParticleEngineClient {
  readonly ServiceName: 'ParticleEngineClient';
  Init(serviceBag: ServiceBag): void;
  SetScreenGui(screenGui: ScreenGui): void;
  Remove(particle: Particle): void;
  Add(particle: Particle): void;
}
