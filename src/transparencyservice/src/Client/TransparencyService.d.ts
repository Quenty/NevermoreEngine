export interface TransparencyService {
  Init(): void;
  IsDead(): boolean;
  SetTransparency(
    key: unknown,
    part: Instance,
    transparency: number | undefined
  ): void;
  SetLocalTransparencyModifier(
    key: unknown,
    part: Instance,
    transparency: number | undefined
  ): void;
  ResetLocalTransparencyModifier(key: unknown, part: Instance): void;
  ResetTransparency(key: unknown, part: Instance): void;
  Destroy(): void;
}
