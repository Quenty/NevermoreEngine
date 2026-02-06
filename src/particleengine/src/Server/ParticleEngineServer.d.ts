export interface ParticleEngineServer {
  readonly ServiceName: 'ParticleEngineServer';
  Init(): void;
  ParticleNew<
    T extends {
      Position: Vector3;
      Velocity?: Vector3;
      Size?: Vector2;
      Bloom?: Vector2;
      Gravity?: Vector3;
      LifeTime: number;
      Color?: Color3;
      Transparency?: number;
    }
  >(
    p: T
  ): T;
}
