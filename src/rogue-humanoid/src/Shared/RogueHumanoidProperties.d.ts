import { RoguePropertyTableDefinition } from '@quenty/rogue-properties';

export const RogueHumanoidProperties: RoguePropertyTableDefinition<{
  WalkSpeed: number;
  JumpHeight: number;
  JumpPower: number;
  CharacterUseJumpPower: number;

  Scale: 1;
  ScaleMax: 20;
  ScaleMin: 0.2;

  MaxHealth: 100;
}>;
